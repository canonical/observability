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
