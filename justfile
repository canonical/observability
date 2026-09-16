set quiet  # Recipes are silent by default
set export  # Just variables are exported to the environment

mod security

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
[group("info")]
list-charms:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -r '.artifacts.charms[].name' manifest.yaml | sort -u

# List all repositories of charms from the manifest
[group("info")]
list-charm-repos:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -r '.artifacts.charms[].repo' manifest.yaml | sort -u

# List all charm releases from the manifest as JSON (name, repo, path, branch, track)
[group("info")]
list-charm-releases:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -o=json manifest.yaml | jq -c '
    [.artifacts.charms[]
      | .name as $name | .repo as $repo | .path as $path
      | .releases[]?
      | {name: $name, repo: $repo, path: $path, branch: .branch, track: .name}]
  '

# List all rocks from the manifest
[group("info")]
list-rocks:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -r '.artifacts.rocks[].name' manifest.yaml | sort -u

# List all repositories of rocks from the manifest
[group("info")]
list-rock-repos:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -r '.artifacts.rocks[].repo' manifest.yaml | sort -u

# List all snaps from the manifest
[group("info")]
list-snaps:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -r '.artifacts.snaps[].name' manifest.yaml | sort -u

# List all repositories of snaps from the manifest
[group("info")]
list-snap-repos:
  #!/usr/bin/env bash
  set -euo pipefail
  yq -r '.artifacts.snaps[].repo' manifest.yaml | sort -u

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

# Set a secret for all charm repositories from the manifest
[group("secrets")]
set-charm-secret secret:
  #!/usr/bin/env bash
  set -euo pipefail
  if [[ -z "${{secret}}" ]]; then
    echo "You must set the {{secret}} environment variable with the secret contents."
    exit 1
  fi
  just list-charm-repos | while read -r repo; do
    gh secret set "{{secret}}" --repo "$repo" --body "${{secret}}"
  done

# Set a secret for all snap repositories from the manifest
[group("secrets")]
set-snap-secret secret:
  #!/usr/bin/env bash
  set -euo pipefail
  if [[ -z "${{secret}}" ]]; then
    echo "You must set the {{secret}} environment variable with the secret contents."
    exit 1
  fi
  just list-snap-repos | while read -r repo; do
    gh secret set "{{secret}}" --repo "$repo" --body "${{secret}}"
  done

# Set a secret for all rock repositories from the manifest
[group("secrets")]
set-rock-secret secret:
  #!/usr/bin/env bash
  set -euo pipefail
  if [[ -z "${{secret}}" ]]; then
    echo "You must set the {{secret}} environment variable with the secret contents."
    exit 1
  fi
  just list-rock-repos | while read -r repo; do
    gh secret set "{{secret}}" --repo "$repo" --body "${{secret}}"
  done

# Promote a charm through all non-dev/non-latest tracks (beta→candidate)
[group("maintenance")]
promote-charm-train charm:
  #!/usr/bin/env bash
  set -euo pipefail
  tracks=$(juju info {{charm}} --format=json | jq -r '.tracks[]')
  for track in $tracks; do
    if [[ "$track" == "dev" || "$track" == "latest" ]]; then
      continue
    fi
    echo "Promoting {{charm}} on track ${track}..."
    # Edge to beta is handled by the beta-quality-gate.yaml workflow.
    # FIXME: gate beta to candidate once a candidate quality gate is in place.
    charmcraft promote --yes --name "{{charm}}" --from-channel="${track}/beta" --to-channel="${track}/candidate"
  done

# Promote a snap through all available tracks (edge→stable)
[group("maintenance")]
promote-snap-train snap:
  #!/usr/bin/env bash
  set -euo pipefail
  tracks=$(snapcraft tracks {{snap}} | tail -n +2 | awk '{print $1}')
  for track in $tracks; do
    echo "Promoting {{snap}} on track ${track}..."
    snapcraft promote --yes {{snap}} --from-channel="${track}/edge" --to-channel="${track}/stable"
  done
