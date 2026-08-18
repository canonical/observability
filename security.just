set quiet  # Recipes are silent by default
set export  # Just variables are exported to the environment

[private]
default:
  just -f security.just --list

# List every charm release as JSON, grouped by unique repo
[group("security")]
scan-matrix:
  #!/usr/bin/env bash
  set -euo pipefail
  # One entry per repo, with the charms/paths/branches it hosts - used by
  # `scan-fleet` to enumerate repos, and by `scan-repo` to look up the charms
  # hosted in one of them.
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

# Scan every charm hosted in one repo for security vulnerabilities
[group("security")]
[arg("repo", help="Repository in 'org/repo' form, as it appears in manifest.yaml")]
scan-repo repo:
  #!/usr/bin/env python3
  # Clones `repo` once and checks out each branch it hosts charms on in turn -
  # only branches that are actually listed in manifest.yaml, nothing else -
  # running `just scan` per charm and writing one result JSON per charm under
  # $RUNNER_TEMP/results (or ./results outside CI). Exits non-zero if any branch
  # failed to check out; vulnerabilities found by `just scan` are recorded but
  # don't fail the recipe. Used by the _local-charm-scan.yaml workflow, but also
  # runs standalone, e.g.: just security::scan-repo canonical/litmus-operators
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

  # A fresh `just` subprocess re-resolves modules from scratch, so sibling
  # recipes in this same module still need their fully-qualified name here.
  matrix = json.loads(subprocess.run(
      ["just", "security::scan-matrix"], capture_output=True, text=True, check=True
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

# Scan every charm across every repo in manifest.yaml, one repo at a time
[group("security")]
scan-fleet:
  #!/usr/bin/env bash
  set -euo pipefail
  # Sequential on purpose: each `scan-repo` call is a shallow clone plus a
  # handful of lightweight `uv audit` runs, so parallelizing this across one
  # runner per repo bought little beyond N-times the runner/artifact overhead.
  # Continues past a repo that fails (matching scan-repo's own per-branch
  # tolerance) but still exits non-zero at the end if any of them did.
  matrix="$(just security::scan-matrix)"
  releases="$(echo "$matrix" | jq '[.[].charms[]] | length')"
  repos="$(echo "$matrix" | jq -r '.[].repo')"
  repo_count="$(echo "$repos" | wc -l)"
  echo "Scanning $releases charm releases across $repo_count repos"

  any_failed=0
  while IFS= read -r repo; do
    just security::scan-repo "$repo" || any_failed=1
  done <<< "$repos"

  exit "$any_failed"

# Build the charm-scan markdown report from a directory of result JSON files
[group("security")]
build-report results_dir="results":
  #!/usr/bin/env python3
  # Searches results_dir recursively, so this works with both a flat directory
  # and the one-artifact-per-repo-subdirectory layout actions/download-artifact
  # produces. Prints the report to stdout - redirect it into $GITHUB_STEP_SUMMARY
  # in CI, or just read it directly when running locally, e.g.:
  #   just security::build-report results
  # Exits non-zero if any result was checkout-failed (does not affect stdout).
  import glob
  import html
  import json
  import sys

  results = []
  for path in glob.glob("{{ results_dir }}/**/*.json", recursive=True):
      with open(path) as f:
          results.append(json.load(f))

  if not results:
      print("# :mag: Charm Security Scan Report\n")
      print("No charm releases found in `manifest.yaml`.")
      sys.exit(0)

  results.sort(key=lambda r: (r["cycle"], r["charm"], r["release"]))

  badges = {
      "pass": "✅",
      "vulnerabilities-found": "⚠️",
      "checkout-failed": "❌",
  }
  status_text = {
      "pass": "pass",
      "vulnerabilities-found": "vulnerabilities found",
      "checkout-failed": "checkout failed",
  }

  counts = {"pass": 0, "vulnerabilities-found": 0, "checkout-failed": 0}
  for r in results:
      counts[r["status"]] += 1

  lines = []
  lines.append("# :mag: Charm Security Scan Report")
  lines.append("")
  lines.append(
      f"**{len(results)} releases scanned** · "
      f"{badges['pass']} {counts['pass']} pass · "
      f"{badges['vulnerabilities-found']} {counts['vulnerabilities-found']} flagged · "
      f"{badges['checkout-failed']} {counts['checkout-failed']} checkout failed"
  )
  lines.append("")

  current_cycle = None
  for r in results:
      if r["cycle"] != current_cycle:
          current_cycle = r["cycle"]
          lines.append(f"## Cycle `{current_cycle}`")
          lines.append("")

      badge = badges[r["status"]]
      lts_label = "LTS" if r["lts"] else "non-LTS"
      summary = (
          f"{badge} <b>{r['charm']}</b> {r['release']} ({lts_label}) "
          f"— {status_text[r['status']]}"
      )
      lines.append("<details>")
      lines.append(f"<summary>{summary}</summary>")
      lines.append("")
      lines.append(f"`{r['repo']}@{r['branch']}`")
      lines.append("")
      lines.append(f"<pre>{html.escape(r['log'])}</pre>")
      lines.append("</details>")
      lines.append("")

  print("\n".join(lines))

  if counts["checkout-failed"] > 0:
      print(f"::error::{counts['checkout-failed']} charm(s) failed to check out; see the report above.", file=sys.stderr)
      sys.exit(1)
