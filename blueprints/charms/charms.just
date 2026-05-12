# Centralized justfile for the Canonical Observability charms
set shell := ["bash", "-uc"]

[private]
default:
    just --list


# Find the merge-base between the current branch and `ref`, then print all commits since.
[group("release")]
[arg("ref", help="Branch (or generic ref) from to get the changelog from")]
changelog ref:
    #!/usr/bin/env bash
    set -euo pipefail
    # Sanitize the ref so that either a branch or a commit is valid
    resolved="{{ ref }}"
    if ! git rev-parse --verify "${resolved}" >/dev/null 2>&1; then
        resolved="origin/{{ ref }}"
    fi
    # Find the merge-base 
    base=$(git merge-base HEAD "${resolved}")
    # Parse all commit messages into a "conventional commits" category
    breaking=""
    features=""
    fixes=""
    others=""
    while IFS= read -r msg; do
        if echo "${msg}" | grep -qE '^[a-z]+(\(.+\))?!:'; then
            breaking="${breaking}- ${msg}"$'\n'
        elif echo "${msg}" | grep -qE '^feat(\(.+\))?:'; then
            features="${features}- ${msg}"$'\n'
        elif echo "${msg}" | grep -qE '^fix(\(.+\))?:'; then
            fixes="${fixes}- ${msg}"$'\n'
        else
            others="${others}- ${msg}"$'\n'
        fi
    done < <(git log --format=%s "${base}..HEAD")
    # Print the commits in a Markdown changelog format
    echo "# Changelog"
    echo ""
    if [ -n "${breaking}" ]; then
        echo "## Breaking Changes"
        echo ""
        echo "${breaking}"
    fi
    if [ -n "${features}" ]; then
        echo "## Features"
        echo ""
        echo "${features}"
    fi
    if [ -n "${fixes}" ]; then
        echo "## Fixes"
        echo ""
        echo "${fixes}"
    fi
    if [ -n "${others}" ]; then
        echo "## Others"
        echo ""
        echo "${others}"
    fi

# Fetch centralized files from canonical/observability
[group("maintenance")]
refresh:
    #!/usr/bin/env bash
    which -s gh || { echo "gh not found"; exit 1; }
    refresh_folder="blueprints/charms"
    api_path="repos/canonical/observability/contents/$refresh_folder"
    for file in charms.just; do
      echo "Fetching latest '$file' from canonical/observability ..."
      gh api "$api_path/$file" --jq '.content' | base64 --decode > "$file"
      echo "✓ $file updated"
    done
