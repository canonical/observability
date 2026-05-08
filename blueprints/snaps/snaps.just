# Centralized justfile for the Canonical Observability snaps
set shell := ["bash", "-uc"]

snap_name := `echo ${PWD##*/} | sed 's/-snap$//'`  # Get the snap name from the folder name
all_architectures := `yq -r '[.platforms | keys[] ] | join(",")' snap/snapcraft.yaml`
# Derive the release channel from the current branch:
#   main          -> latest/edge
#   track/X.Y     -> X.Y/edge
#   other         -> latest/edge/<branch>
branch := `git rev-parse --abbrev-ref HEAD`
channel := if branch == "main" { "latest/edge" } else if branch =~ '^track/.*' { replace_regex(branch, "^track/", "") + "/edge" } else { "latest/edge/" + branch }

[private]
@default:
  just --list
  echo "{{snap_name}}"
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Print the snap name
[group("info")]
@name:
  echo "{{snap_name}}"

# Print the current branch and release channel
[group("info")]
@channel:
  echo "branch: {{branch}} → channel: {{channel}}"

# Remote-build, upload and release a snap to the Snap Store
[group("release")]
release build_for=all_architectures:
  #!/usr/bin/env bash
  set -e
  echo "Starting remote build for architecture(s): {{build_for}} ..."
  snapcraft remote-build --build-for="{{build_for}}"
  snap_files=(*.snap)
  if [[ ${#snap_files[@]} -eq 0 || ! -e "${snap_files[0]}" ]]; then
    echo "× Error: no snap files found after remote build."
    exit 1
  fi
  for snap_file in "${snap_files[@]}"; do
    echo "Uploading and releasing $snap_file to {{channel}} ..."
    snapcraft upload "$snap_file" --release="{{channel}}"
    echo "✓ {{snap_name}} ($snap_file) released to {{channel}}"
  done

# Fetch centralized files from canonical/observability
[group("maintenance")]
refresh:
  #!/usr/bin/env bash
  which -s gh || { echo "gh not found"; exit 1; }
  refresh_folder="blueprints/snaps"
  api_path="repos/canonical/observability/contents/$refresh_folder"
  for file in snaps.just spread.yaml; do
    echo "Fetching latest '$file' from canonical/observability ..."
    gh api "$api_path/$file" --jq '.content' | base64 --decode > "$file"
    echo "✓ $file updated"
  done
