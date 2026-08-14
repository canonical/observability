# Centralized justfile for the Canonical Observability rocks
set shell := ["bash", "-uc"]

rock_name := `echo ${PWD##*/} | sed 's/-rock$//'`  # Get the rock name from the folder name

# Latest maintained version, i.e. the newest major.minor folder
latest_version := `find . -maxdepth 1 -type d -regextype posix-extended -regex '\./[0-9]+\.[0-9]+' -printf '%f\n' | sort -V | tail -n1`

# Upstream project repository in 'org/repo' form. Override this variable in the local 'justfile'.
# Example: source_repo := 'prometheus/alertmanager'
source_repo := ''

[private]
@default:
  just --list
  echo "{{rock_name}}"
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Print the rock name
[group("info")]
@name:
  echo "{{rock_name}}"

# Print the latest major.minor version
[group("info")]
@latest-version:
  echo "{{latest_version}}"

# Push an OCI image to a local registry
[private]
@push-to-registry version=latest_version:
  which -s docker || { echo "× docker not found"; exit 1; }
  test -f "{{version}}"/*.rock || (cd "{{version}}" && rockcraft pack)
  echo "Pushing {{version}} to local docker registry"
  cd {{version}}; sudo rockcraft.skopeo --insecure-policy copy --dest-tls-verify=false "oci-archive:$(ls *.rock)" docker-daemon:rockcraft-test:latest
  echo "✓ Rock pushed to local registry under 'rockcraft-test:latest'"

# Pack a rock of a specific version (major.minor folder)
[group("dev")]
pack version=latest_version:
  cd "{{version}}" && rockcraft pack

# `rockcraft clean` for a specific version (major.minor folder)
[group("dev")]
clean version=latest_version:
  cd "{{version}}" && rockcraft clean

# Run a rock and open a shell into it with `docker`
[group("dev")]
run version=latest_version: (push-to-registry version)
  which -s dgoss || { echo "× dgoss not found"; exit 1; }
  dgoss edit rockcraft-test:latest || true

# Test a rock with `rockcraft test`
[group("dev")]
test version=latest_version:
  #!/usr/bin/env bash
  set -e
  cp spread.yaml "{{version}}/spread.yaml"
  if [ -f goss.yaml ]; then cp goss.yaml "{{version}}/goss.yaml"; fi
  test_exit=0; (cd "{{version}}" && rockcraft test) || test_exit=$?
  rm -f "{{version}}/spread.yaml" "{{version}}/goss.yaml"
  if [ "$test_exit" -ne 0 ]; then echo "× rockcraft test failed"; exit "$test_exit"; fi
  echo "✓ 'rockcraft test' passed."

# Generate SBOM for the rock
[group("security")]
sbom version=latest_version:
  syft {{version}}/*.rock -o "spdx-json={{version}}/rock.sbom.json"
  @echo "✓ SBOM saved to {{version}}/rock.sbom.json"

# Perform a security scan
[group("security")]
scan version=latest_version: (sbom version)
  uvx --from=trivy-py trivy sbom "{{version}}/rock.sbom.json"
  @echo "✓ Vulnerability scan done"

# Check whether CVEs affect the upstream project
[group("security")]
govulncheck version=latest_version:
  #!/usr/bin/env bash
  set -e
  [[ -z "{{source_repo}}" ]] && { echo "× Set 'source_repo' in the local justfile"; exit 1; }
  # Resolve the real upstream tag from the rockcraft.yaml (folder name is not the version)
  source_tag="$(yq -r '.parts.{{rock_name}}["source-tag"]' "{{version}}/rockcraft.yaml")"
  echo "Cloning {{source_repo}} at $source_tag"
  which -s govulncheck || { echo "govulncheck not found; install it with:  go install golang.org/x/vuln/cmd/govulncheck@latest"; exit 1; }
  TMP_DIR="$(mktemp -d)"
  gh repo clone "{{source_repo}}" "$TMP_DIR/{{source_repo}}" -- --branch "$source_tag" --depth 1
  if [[ ! -f "$TMP_DIR/{{source_repo}}/go.mod" ]]; then
    echo "⨯ {{source_repo}} is not a Go project (go.mod is missing)"
    exit 2
  fi
  echo "Running 'govulncheck' (this may take a while)"
  vuln_exit=0; (cd "$TMP_DIR/{{source_repo}}" && govulncheck ./...) || vuln_exit=$?
  rm -rf "$TMP_DIR"
  if [ "$vuln_exit" -ne 0 ]; then echo "⨯ 'govulncheck' failed"; exit "$vuln_exit"; fi
  echo "✓ 'govulncheck' passed."

# Print "<version> <tag>" for the newest upstream release on a major.minor line
[private]
@resolve-tag major_minor:
  gh release list --repo {{source_repo}} --exclude-pre-releases --limit=200 --json tagName --jq '.[].tagName' \
    | while read -r t; do \
        v="${t#mimir-}"; v="${v#cmd/builder/v}"; v="${v#v}"; \
        [[ "$(echo "$v" | grep -oP '^\d+\.\d+')" == "{{major_minor}}" ]] && echo "$v $t"; \
      done \
    | sort -V | tail -n1

# Write a version + source-tag into a folder's rockcraft.yaml (and refresh Go build-snap)
[private]
write-version folder version tag:
  #!/usr/bin/env bash
  set -e
  file="{{folder}}/rockcraft.yaml"
  version="{{version}}" tag="{{tag}}" yq -i \
    '.version = strenv(version) | .parts.{{rock_name}}["source-tag"] = strenv(tag)' \
    "$file"
  TMP_DIR="$(mktemp -d)"
  gh repo clone "{{source_repo}}" "$TMP_DIR/src" -- --branch "{{tag}}" --depth 1 2>/dev/null || true
  if [[ -f "$TMP_DIR/src/go.mod" ]]; then
    go_snap_version="$(grep -Po '^go \K(\S+)' "$TMP_DIR/src/go.mod" | sed -E 's/([0-9]+\.[0-9]+).*/\1/')"
    go_snap_version="$go_snap_version" yq -i \
      '(.parts.{{rock_name}}.build-snaps[] | select(test("^go/"))) = "go/"+strenv(go_snap_version)+"/candidate"' \
      "$file"
  fi
  rm -rf "$TMP_DIR"

# Create a new major.minor folder, resolving the newest real upstream tag on that line
[group("maintenance")]
add-version version:
  #!/usr/bin/env bash
  set -e
  [[ -z "{{source_repo}}" ]] && { echo "× Set 'source_repo' in the local justfile"; exit 1; }
  # Normalize the requested version to a major.minor line
  requested="{{version}}"
  requested="${requested#mimir-}"; requested="${requested#cmd/builder/v}"; requested="${requested#v}"
  major_minor="$(echo "$requested" | grep -oP '^\d+\.\d+')"
  [[ -z "$major_minor" ]] && { echo "× could not parse a major.minor from '{{version}}'"; exit 1; }
  [[ -d "$major_minor" ]] && { echo "→ $major_minor/ already exists, nothing to do"; exit 0; }
  # Resolve the newest upstream tag on this line before touching anything
  read -r version tag < <(just resolve-tag "$major_minor")
  [[ -z "$version" ]] && { echo "× no upstream release found for {{source_repo}} on the $major_minor line"; exit 1; }
  # Seed from the newest existing minor folder, then pin the resolved version
  template="{{latest_version}}"
  [[ -z "$template" ]] && { echo "× no existing X.Y folder to copy from"; exit 1; }
  echo "Seeding $major_minor/ from $template/ ..."
  cp -r "$template" "$major_minor"
  just write-version "$major_minor" "$version" "$tag"
  echo "✓ Created $major_minor/ at $version (source-tag $tag)"

# Patch all existing major.minor folders to the newest upstream patch version
[group("maintenance")]
update:
  #!/usr/bin/env bash
  set -e
  [[ -z "{{source_repo}}" ]] && { echo "× Set 'source_repo' in the local justfile"; exit 1; }
  updated_folders=""
  for folder in $(find . -maxdepth 1 -type d -regextype posix-extended -regex '\./[0-9]+\.[0-9]+' -printf '%f\n' | sort -V); do
    read -r version tag < <(just resolve-tag "$folder")
    if [[ -z "$version" ]]; then echo "→ no upstream patch found for $folder, skipping"; continue; fi
    current="$(yq -r '.version' "$folder/rockcraft.yaml")"
    if [[ "$current" == "$version" ]]; then echo "→ $folder already at $version"; continue; fi
    echo "Updating $folder: $current → $version (source-tag $tag)"
    just write-version "$folder" "$version" "$tag"
    updated_folders="$updated_folders $folder"
  done
  if [[ -n "$updated_folders" ]]; then echo; echo "✓ Versions updated"; fi

# Fetch centralized files from canonical/observability
[group("maintenance")]
refresh:
  #!/usr/bin/env bash
  which -s gh || { echo "gh not found"; exit 1; }
  refresh_folder="blueprints/rocks"
  api_path="repos/canonical/observability/contents/$refresh_folder"
  for file in rocks.just spread.yaml; do
    echo "Fetching latest '$file' from canonical/observability ..."
    gh api "$api_path/$file" --jq '.content' | base64 --decode > "$file"
    echo "✓ $file updated"
  done

# Release rock to GHCR with tag `:dev`
[group("release")]
release-ghcr version=latest_version github_user="observability-noctua-bot":
  #!/usr/bin/env bash
  set -e
  if [[ -z "$GITHUB_TOKEN" ]]; then echo "× Please export GITHUB_TOKEN for the user {{github_user}}"; exit 1; fi
  if [ ! -e {{version}}/*.rock ]; then echo "× Error: rock not found. Please run 'just pack {{version}}' first."; exit 2; fi
  sudo rockcraft.skopeo --insecure-policy copy \
    "oci-archive:$(realpath ./{{version}}/*.rock)" \
    "docker://ghcr.io/canonical/{{rock_name}}:dev" \
    --dest-creds "{{github_user}}:${GITHUB_TOKEN}"
  echo "✓ {{rock_name}} {{version}} pushed to GHCR with tag ':dev'"

# Open a PR to OCI Factory
[group("release")]
[arg("support",pattern="major|minor|patch")]
[arg("risk", pattern="stable|candidate|beta|edge")]
release-oci-factory version=latest_version support="minor" risk="stable":
  #!/usr/bin/env bash
  set -e
  if [[ -z "$GITHUB_TOKEN" ]]; then echo "× Please export GITHUB_TOKEN for the user observability-noctua-bot"; exit 1; fi
  if [ ! -e {{version}}/*.rock ]; then echo "× Error: rock not found. Please run 'just pack {{version}}' first."; exit 2; fi
  repository="$(git remote get-url origin | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s/\.git$//')"
  # Read the real semver from the rockcraft.yaml (folder name is 'X.Y')
  rock_version="$(yq -r '.version' "{{version}}/rockcraft.yaml")"
  # Extract the base from the rockcraft.yaml (e.g. "ubuntu@24.04" -> "24.04")
  # For bare-based rocks, fall back to build-base (e.g. "ubuntu@26.04" -> "26.04")
  rock_base="$(yq -r '.base' "{{version}}/rockcraft.yaml" | sed 's/.*@//')"
  if [[ "$rock_base" == "bare" ]]; then
    rock_base="$(yq -r '.["build-base"]' "{{version}}/rockcraft.yaml" | sed 's/.*@//')"
  fi
  echo "Detected version: $rock_version, base: $rock_base"
  # Clone the oci-factory and push data to it
  gh repo sync --force observability-noctua-bot/oci-factory
  TMP_DIR="$(mktemp -d)"
  git clone https://github.com/observability-noctua-bot/oci-factory "$TMP_DIR/oci-factory"
  echo "✓ Cloned observability-noctua-bot/oci-factory"
  echo "Building the OCI Factory manifest..."; echo
  manifest_file="$TMP_DIR/oci-factory/oci/{{rock_name}}/image.yaml"
  uvx --from=git+https://github.com/lucabello/noctua noctua rock manifest \
    "$repository" \
    --commit="$(git rev-parse HEAD)" \
    --base="$rock_base" \
    --support="{{support}}" \
    --risk="{{risk}}" \
    --version="$rock_version" \
    | tee "$manifest_file"
  echo; echo "✓ OCI Factory manifest generated"
  # If there's nothing to upload, exit early
  upload_count="$(cat "$manifest_file" | yq '.upload | length')"
  if [[ "$upload_count" -eq 0 ]]; then
    echo "✓ Nothing to update in OCI Factory"
    rm -rf "$TMP_DIR"
    exit 0
  fi
  # Commit the changes and create a PR
  pushd "$TMP_DIR/oci-factory" >/dev/null
  git config user.name observability-noctua-bot
  git config user.email webops+observability-noctua-bot@canonical.com
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/observability-noctua-bot/oci-factory.git"
  branch_name="update-$(date -d now +%s)"
  git checkout -b "$branch_name"
  git add oci/{{rock_name}}/image.yaml
  git commit -m "chore: Add new {{rock_name}} releases"
  git push -u origin "$branch_name" --force
  echo "✓ Changes have been pushed to ${branch_name}"
  gh pr create --repo canonical/oci-factory \
    --head "observability-noctua-bot:${branch_name}" \
    --title "chore: Add new {{rock_name}} releases" \
    --body "This is an automatic PR opened by the Observability Noctua bot."
  popd >/dev/null
  rm -rf "$TMP_DIR"
  echo "✓ Release to OCI Factory completed"
