set quiet  # Recipes are silent by default
set export  # Just variables are exported to the environment

[private]
default:
  just --list

# Lint everything
[group("dev")]
lint:
  # Lint the GitHub workflows
  uvx --from=actionlint-py actionlint

# List all repositories owned by the Observability teams, deduped and sorted
[group("info")]
list-repos:
  #!/usr/bin/env bash
  set -euo pipefail
  # GitHub team slugs under the 'canonical' org (bare slugs, no 'canonical/' prefix)
  teams=(observability tracing-and-profiling observability-core)
  # Repos to exclude, as full names (e.g. canonical/observability)
  ignore=(canonical/observability)
  {
    for team in "${teams[@]}"; do
      gh api "orgs/canonical/teams/${team}/repos" --paginate \
        | jq -r '.[] | select(.archived == false and .disabled == false) | .full_name'
    done
  } | { grep -vxF -f <(printf '%s\n' "${ignore[@]}") || true; } | sort -u

# List all charms from the manifest
[group("manifest")]
list-charms:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -r '.artifacts.charms[].name' manifest.yaml | sort -u

# List all rocks from the manifest
[group("manifest")]
list-rocks:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -r '.artifacts.rocks[].name' manifest.yaml | sort -u

# List all snaps from the manifest
[group("manifest")]
list-snaps:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -r '.artifacts.snaps[].name' manifest.yaml | sort -u

# List all releases from the manifest that are past their end of life
[group("manifest")]
list-expired:
  #!/usr/bin/env bash
  set -euo pipefail
  today=$(date +%F)
  yq -o=json manifest.yaml | jq -r --arg today "$today" '
    .artifacts
    | to_entries[]
    | .key as $type
    | .value[]
    | .name as $artifact
    | .releases[]?
    | select(.support.end_of_life != null and .support.end_of_life < $today)
    | [$type, $artifact, .name, .support.end_of_life] | @tsv
  ' | column -t -s $'\t'

# List the charm-scan matrix as JSON, one entry per unique repo
[group("manifest")]
list-scan-matrix:
  #!/usr/bin/env bash
  set -euo pipefail
  # One entry per repo, with the charms/paths/branches it hosts - used as the
  # matrix for the _local-charm-scan.yaml workflow (see also: `just scan-repo`).
  yq -o=json manifest.yaml | jq -c '
    [.artifacts.charms[]
      | .name as $charm | .repo as $repo | .path as $path
      | .releases[]?
      | {
          repo: $repo,
          branch: .branch,
          charm: $charm,
          path: $path,
          release: .name,
          cycle: (.cycle | tostring),
          lts: (.support.lts // false)
        }
    ]
    | group_by(.repo)
    | map({
        repo: .[0].repo,
        charms: map({charm, path, release, branch, cycle, lts})
      })
  '

# Remove releases from the manifest that are past their end of life
[group("manifest")]
remove-expired:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "Removing the following EOL releases:"
  just list-expired
  export TODAY=$(date +%F)
  yq -i '
    (.. | select(has("releases")) | .releases)
    |= map(select(.support.end_of_life == null or .support.end_of_life >= strenv(TODAY)))
  ' manifest.yaml

# Set a secret for all unarchived repositories of one or more GitHub teams
[group("secrets")]
set-team-secret secret +teams:
  #!/usr/bin/env bash
  set -euo pipefail
  if [[ -z "${{secret}}" ]]; then
    echo "You must set the {{secret}} environment variable with the secret contents."
    exit 1
  fi
  for team in {{teams}}; do
    gh api "orgs/canonical/teams/${team}/repos" --paginate \
      | jq -r '.[] | select(.archived == false and .disabled == false) | .full_name'
  done | sort -u | while read -r repo; do
    gh secret set "{{secret}}" --repo "$repo" --body "${{secret}}"
  done

# Promote a charm through all non-dev/non-latest tracks (beta→candidate, edge→beta)
[group("maintenance")]
promote-train charm:
  #!/usr/bin/env bash
  set -euo pipefail
  tracks=$(juju info {{charm}} --format=json | jq -r '.tracks[]')
  for track in $tracks; do
    if [[ "$track" == "dev" || "$track" == "latest" ]]; then
      continue
    fi
    echo "Promoting {{charm}} on track ${track}..."
    # FIXME: We're shortcircuiting this until we have quality gates in place, so that `/edge` goes directly to `/candidate`
    # charmcraft promote --yes --name "{{charm}}" --from-channel="${track}/beta" --to-channel="${track}/candidate"
    # charmcraft promote --yes --name "{{charm}}" --from-channel="${track}/edge" --to-channel="${track}/beta"
    charmcraft promote --yes --name "{{charm}}" --from-channel="${track}/edge" --to-channel="${track}/beta"
    charmcraft promote --yes --name "{{charm}}" --from-channel="${track}/edge" --to-channel="${track}/candidate"
  done

# Scan every charm hosted in one repo for security vulnerabilities
[group("scan")]
[arg("repo", help="Repository in 'org/repo' form, as it appears in manifest.yaml")]
scan-repo repo:
  #!/usr/bin/env python3
  # Clones `repo` once and checks out each branch it hosts charms on in turn,
  # running `just scan` per charm and writing one result JSON per charm under
  # $RUNNER_TEMP/results (or ./results outside CI). Exits non-zero if any branch
  # failed to check out; vulnerabilities found by `just scan` are recorded but
  # don't fail the recipe. Used by the _local-charm-scan.yaml workflow, but also
  # runs standalone, e.g.: just scan-repo canonical/litmus-operators
  import json
  import os
  import subprocess
  import sys
  from pathlib import Path

  repo = "{{ repo }}"
  results_dir = Path(os.environ.get("RUNNER_TEMP", ".")) / "results"
  results_dir.mkdir(parents=True, exist_ok=True)

  def run(*args, cwd=None):
      # Merge stdout/stderr (like a shell's `2>&1`) so captured logs read in order.
      return subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

  def record(charm, release, cycle, lts, branch, status, log):
      result = {
          "charm": charm, "release": release, "cycle": cycle, "lts": lts,
          "repo": repo, "branch": branch, "status": status,
          "log": log or "(no output captured)",
      }
      (results_dir / f"{charm}-{release}.json").write_text(json.dumps(result))

  matrix = json.loads(subprocess.run(
      ["just", "list-scan-matrix"], capture_output=True, text=True, check=True
  ).stdout)
  entry = next((e for e in matrix if e["repo"] == repo), None)
  charms = entry["charms"] if entry else []
  if not charms:
      print(f"No charms found for repo '{repo}' in manifest.yaml", file=sys.stderr)
      sys.exit(1)

  checkout_dir = Path("charm-checkout")
  clone = run(
      "git", "clone", "--quiet", "--no-checkout", "--depth=1", "--no-single-branch",
      f"https://github.com/{repo}.git", str(checkout_dir),
  )

  any_failed = False
  if clone.returncode != 0:
      any_failed = True
      for c in charms:
          record(c["charm"], c["release"], c["cycle"], c["lts"], c["branch"], "checkout-failed", clone.stdout)
  else:
      for branch in sorted({c["branch"] for c in charms}):
          checkout = run("git", "checkout", "--quiet", "-B", branch, f"origin/{branch}", cwd=checkout_dir)
          branch_ok = checkout.returncode == 0
          any_failed = any_failed or not branch_ok

          for c in (c for c in charms if c["branch"] == branch):
              if not branch_ok:
                  status, log = "checkout-failed", checkout.stdout
              else:
                  scan = run("just", "scan", cwd=checkout_dir / c["path"])
                  status = "pass" if scan.returncode == 0 else "vulnerabilities-found"
                  log = scan.stdout
              record(c["charm"], c["release"], c["cycle"], c["lts"], branch, status, log)

  if any_failed:
      print(f"::error::One or more branches of {repo} failed to check out", file=sys.stderr)
      sys.exit(1)
