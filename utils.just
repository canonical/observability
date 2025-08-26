set quiet

gh := `which gh`

[private]
default:
  just -f {{justfile_directory()}}/utils.just --list

# Show unarchived repos owned by the specified team on GitHub
[group("info")]
list-repos team:  # We currently have 'observability', 'observability-core', 'tracing-and-profiling', 'service-mesh'
  gh api "orgs/canonical/teams/{{team}}/repos" --paginate | jq -r '.[] | select(.archived == false and .disabled == false) | .full_name' | sort

# Set a secret for all the unarchived the repositories of a GitHub team
[group("secrets")]
set-team-secret team secret:
  #!/usr/bin/env bash
  # Make sure the secret is set in an environment variable
  if [[ -z "${{secret}}" ]]; then
    echo "You must set the {{secret}} environment variable with the secret contents."
    exit 1
  fi
  # Gather the unarchived team repos
  repos="$(just -f {{justfile_directory()}}/utils.just list-repos {{team}})"
  # Set the secrets
  for repo in $repos; do
    gh secret set "{{secret}}" --repo "$repo" --body "${{secret}}"
  done
    

