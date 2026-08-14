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

# Generate manifest.yaml (charms, rocks, snaps with their supported branches)
[group("manifest")]
generate-manifest:
  #!/usr/bin/env bash
  set -euo pipefail
  # GitHub team slugs under the 'canonical' org (bare slugs, no 'canonical/' prefix)
  teams="observability,tracing-and-profiling,observability-core"
  # Repos to exclude, as full names (e.g. canonical/observability)
  ignore="canonical/observability"
  scripts/generate_manifest.py "${teams}" "${ignore}"

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
  if [[ ! -f manifest.yaml ]]; then
    echo "manifest.yaml not found; run 'just generate-manifest' first." >&2
    exit 1
  fi
  yq -r '.repositories.charms[].charm' manifest.yaml | sort -u

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
