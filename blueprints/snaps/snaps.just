# Centralized justfile for the Canonical Observability snaps
set shell := ["bash", "-uc"]

snap_name := `echo ${PWD##*/} | sed 's/-snap$//'`  # Get the snap name from the folder name

[private]
@default:
  just --list
  echo "{{snap_name}}"
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Print the snap name
[group("info")]
@name:
  echo "{{snap_name}}"

# Print comma-separated list of platforms from snapcraft.yaml
[group("info")]
@platforms version="latest":
  yq -r '[.platforms | keys[]] | join(",")' "{{version}}/snap/snapcraft.yaml"

# Pack a snap locally for a specific version and architecture
[group("dev")]
pack version="latest" build_for="amd64":
  cd "{{version}}" && snapcraft pack --build-for="{{build_for}}"

# Test a snap with `snapcraft test`
[group("dev")]
test version="latest":
  #!/usr/bin/env bash
  set -e
  cp spread.yaml "{{version}}/spread.yaml"
  test_exit=0; (cd "{{version}}" && snapcraft test) || test_exit=$?
  rm -f "{{version}}/spread.yaml"
  if [ "$test_exit" -ne 0 ]; then echo "× snapcraft test failed"; exit "$test_exit"; fi
  echo "✓ 'snapcraft test' passed."

# Promote a snap to the next risk level (edge→beta→candidate→stable)
[group("release")]
[arg("from_risk", pattern="candidate|beta|edge")]
promote version="latest" from_risk="edge":
  #!/usr/bin/env bash
  set -e
  case "{{from_risk}}" in
    edge)      to_risk="beta" ;;
    beta)      to_risk="candidate" ;;
    candidate) to_risk="stable" ;;
    *) echo "× Error: invalid risk '{{from_risk}}'. Must be one of: edge, beta, candidate." && exit 1 ;;
  esac
  from_channel="{{version}}/${from_risk}"
  to_channel="{{version}}/${to_risk}"
  echo "Promoting {{snap_name}} from $from_channel → $to_channel ..."
  snapcraft promote {{snap_name}} --from-channel="$from_channel" --to-channel="$to_channel" --yes
  echo "✓ {{snap_name}} promoted to $to_channel"

# Remote-build a snap for a specific version and architecture
[group("release")]
remote-build version="latest" build_for="amd64":
  #!/usr/bin/env bash
  set -e
  cd "{{version}}"
  # snapcraft remote-build requires a git repository to be present
  git init
  echo "Starting remote build for {{snap_name}} {{version}} ({{build_for}}) ..."
  snapcraft remote-build --build-for="{{build_for}}" --launchpad-accept-public-upload
  echo "✓ Remote build complete. Snap files are in {{version}}/"

# Upload and release all snap files in the version folder to the Snap Store
[group("release")]
release version="latest":
  #!/usr/bin/env bash
  set -e
  cd "{{version}}"
  snap_files=(*.snap)
  if [[ ${#snap_files[@]} -eq 0 || ! -e "${snap_files[0]}" ]]; then
    echo "× Error: no snap files found in {{version}}/"
    exit 1
  fi
  channel="{{version}}/edge"
  for snap_file in "${snap_files[@]}"; do
    echo "Uploading and releasing $snap_file to $channel ..."
    snapcraft upload "$snap_file" --release="$channel"
    echo "✓ {{snap_name}} ($snap_file) released to $channel"
  done

# Update the snap to the latest upstream version
[arg("source_repo", help="Repository of the upstream project in 'org/repo' form")]
[group("maintenance")]
update source_repo:
  #!/usr/bin/env bash
  set -e

  # Fetch the latest upstream release
  latest_release="$(gh release list --repo {{source_repo}} --exclude-pre-releases --limit=1 --json tagName --jq '.[0].tagName')"
  echo "Latest release for {{source_repo}} is $latest_release"

  # Parse full semver (X.Y.Z) and major.minor (X.Y)
  full_version="${latest_release#v}"  # Strip v- prefix
  major_minor="$(echo "$full_version" | grep -oP '^\d+\.\d+')"
  if [[ -z "$major_minor" ]]; then
    echo "× Error: could not parse version from '$latest_release'"
    exit 1
  fi

  # Get current version from latest/ folder
  if [[ ! -f "latest/snap/snapcraft.yaml" ]]; then
    echo "× Error: latest/snap/snapcraft.yaml not found"
    exit 1
  fi
  current_version="$(yq -r '.version' latest/snap/snapcraft.yaml)"

  # Compare versions using sort -V (version sort)
  newer_version="$(printf '%s\n%s' "$current_version" "$full_version" | sort -V | tail -n1)"
  if [[ "$newer_version" == "$current_version" && "$full_version" != "$current_version" ]]; then
    echo "Current version ($current_version) is newer than or equal to upstream ($full_version), nothing to do"
    exit 0
  fi
  if [[ "$full_version" == "$current_version" ]]; then
    echo "Already at version $full_version, nothing to do"
    exit 0
  fi

  updated_folders=""

  # Update the latest/ folder
  echo "Updating latest/ folder to version $full_version ..."
  full_version="$full_version" yq -i '.version = strenv(full_version)' "latest/snap/snapcraft.yaml"
  updated_folders="latest"
  echo "✓ Updated latest/ to $full_version"

  # Update the X.Y/ folder if it exists (no auto-creation)
  if [[ -d "$major_minor" ]]; then
    echo "Updating $major_minor/ folder to version $full_version ..."
    full_version="$full_version" yq -i '.version = strenv(full_version)' "$major_minor/snap/snapcraft.yaml"
    updated_folders="$updated_folders $major_minor"
    echo "✓ Updated $major_minor/ to $full_version"
  else
    echo "No $major_minor/ folder exists, skipping track-specific update"
  fi

  echo "updated_folders=$updated_folders"
  echo "new_version=$full_version"

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
