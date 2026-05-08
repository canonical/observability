# Centralized justfile for the Canonical Observability snaps
set shell := ["bash", "-uc"]

snap_name := `echo ${PWD##*/} | sed 's/-snap$//'`  # Get the snap name from the folder name
latest_version := `find . -name snapcraft.yaml -printf '%h\n' | sed 's@./@@; s@/snap@@' | sort -V | tail -n1`

[private]
@default:
  just --list
  echo "{{snap_name}}"
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Print the snap name
[group("info")]
@name:
  echo "{{snap_name}}"

# Print the latest snap version
[group("info")]
@latest-version:
  echo "{{latest_version}}"

# Print comma-separated list of platforms from snapcraft.yaml
[group("info")]
@platforms version=latest_version:
  yq -r '[.platforms | keys[]] | join(",")' "{{version}}/snap/snapcraft.yaml"

# Pack a snap locally for a specific version and architecture
[group("dev")]
pack version=latest_version build_for="amd64":
  cd "{{version}}" && snapcraft pack --build-for="{{build_for}}"

# Promote a snap to the next risk level (edge→beta→candidate→stable)
[group("release")]
promote version=latest_version from_risk="edge":
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

# Remote-build, upload and release a snap to the Snap Store
[group("release")]
release version=latest_version build_for="amd64":
  #!/usr/bin/env bash
  set -e
  channel="{{version}}/edge"
  # snapcraft remote-build requires a git repository to be present
  git init
  echo "Starting remote build for {{snap_name}} {{version}} ({{build_for}}) ..."
  cd "{{version}}"
  snapcraft remote-build --build-for="{{build_for}}"
  snap_files=(*.snap)
  if [[ ${#snap_files[@]} -eq 0 || ! -e "${snap_files[0]}" ]]; then
    echo "× Error: no snap files found after remote build."
    exit 1
  fi
  channels="$channel"
  if [[ "{{version}}" == "{{latest_version}}" ]]; then
    channels="$channel,latest/edge"
  fi
  for snap_file in "${snap_files[@]}"; do
    echo "Uploading and releasing $snap_file to $channels ..."
    snapcraft upload "$snap_file" --release="$channels"
    echo "✓ {{snap_name}} ($snap_file) released to $channels"
  done

# Generate a snap for the latest version of the upstream project
[arg("source_repo", help="Repository of the upstream project in 'org/repo' form")]
[group("maintenance")]
update source_repo:
  #!/usr/bin/env bash
  set -e
  latest_release="$(gh release list --repo {{source_repo}} --exclude-pre-releases --limit=1 --json tagName --jq '.[0].tagName')"
  echo "Latest release for {{source_repo}} is $latest_release"
  version="${latest_release}"
  version="${version#v}"  # Strip generic v- prefix
  # Use only major.minor for the folder name
  version="$(echo "$version" | grep -oP '^\d+\.\d+')"
  if [[ -z "$version" ]]; then
    echo "× Error: could not parse major.minor version from '$latest_release'"
    exit 1
  fi
  # If the version already exists, exit here
  if [[ -d "$version" ]]; then echo "Folder $version already exists, nothing to do" && exit 0; fi
  # Create the folder for the new version and update the snapcraft.yaml
  cp -r "{{latest_version}}" "$version"
  version="$version" yq -i \
    '.version = strenv(version)' \
    "./$version/snap/snapcraft.yaml"
  echo "✓ Created snap for version $version"

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
