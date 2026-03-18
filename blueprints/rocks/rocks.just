# Centralized justfile for the Canonical Observability rocks
set shell := ["bash", "-uc"]

rock_name := `echo ${PWD##*/} | sed 's/-rock$//'`  # Get the rock name from the folder name
latest_version := `find . -name rockcraft.yaml -printf '%h\n' | sort -V | tail -n1 | sed 's@./@@'`

[private]
@default:
  just --list
  echo "{{rock_name}}"
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Push an OCI image to a local registry
[private]
@push-to-registry version=latest_version:
  which -s docker || { echo "docker not found"; exit 1; }
  test -f "{{version}}/{{rock_name}}_{{version}}_amd64.rock" || rockcraft pack
  echo "Pushing {{version}} to local docker registry"
  cd {{version}}; sudo rockcraft.skopeo --insecure-policy copy --dest-tls-verify=false "oci-archive:{{rock_name}}_{{version}}_amd64.rock" docker-daemon:rockcraft-test:latest
  echo "✓ Rock pushed to local registry under 'rockcraft-test:latest'"

# Print the rock name
[group("info")]
@name:
  echo "{{rock_name}}"

# Print the latest rock version
[group("info")]
@latest-version:
  echo "{{latest_version}}"

# Pack a rock of a specific component and version
[group("dev")]
pack version=latest_version:
  cd "{{version}}" && rockcraft pack

# `rockcraft clean` for a specific component and version
[group("dev")]
clean version=latest_version:
  cd "{{version}}" && rockcraft clean

# Run a rock and open a shell into it with `docker`
[group("dev")]
run version=latest_version: (push-to-registry version)
  which -s dgoss || { echo "dgoss not found"; exit 1; }
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

# Perform a securiy scan
[group("security")]
scan version=latest_version: (sbom version)
  uvx --from=trivy-py trivy sbom "{{version}}/rock.sbom.json"
  @echo "✓ Vulnerability scan done"

# Check whether CVEs affect the upstream project
[group("security")]
govulncheck source_repo version=latest_version:
  #!/usr/bin/env bash
  set -e
  echo "Cloning {{source_repo}}"
  which -s govulncheck || { echo "govulncheck not found; install it with:  go install golang.org/x/vuln/cmd/govulncheck@latest"; exit 1; }
  TMP_DIR="$(mktemp -d)"
  gh repo clone "{{source_repo}}" "$TMP_DIR/{{source_repo}}" -- --branch "{{version}}" --depth 1 2>/dev/null \
    || gh repo clone "{{source_repo}}" "$TMP_DIR/{{source_repo}}" -- --branch "v{{version}}" --depth 1
  if [[ ! -f "$TMP_DIR/{{source_repo}}/go.mod" ]]; then
    echo "⨯ {{source_repo}} is not a Go project (go.mod is missing)"
    exit 2
  fi
  echo "Running 'govulncheck' (this may take a while)"
  vuln_exit=0; (cd "$TMP_DIR/{{source_repo}}" && govulncheck ./...) || vuln_exit=$?
  rm -rf "$TMP_DIR"
  if [ "$vuln_exit" -ne 0 ]; then echo "⨯ 'govulncheck' failed"; exit "$vuln_exit"; fi
  echo "✓ 'govulncheck' passed."

# Generate a rock for the latest version of the upstream project
[arg("source_repo", help="Repository of the upstream project in 'org/repo' form")]
[group("maintenance")]
update source_repo release_tag="":
  #!/usr/bin/env bash
  set -e
  if [[ -z "{{release_tag}}" ]]; then
    latest_release="$(gh release list --repo {{source_repo}} --exclude-pre-releases --limit=1 --json tagName --jq '.[0].tagName')"
    echo "Latest release for {{source_repo}} is $latest_release"
  else
    latest_release="{{release_tag}}"
    echo "Release version manually set to $latest_release"
  fi
  # Explicitly filter out prefixes for known rocks, so we can notice if a new rock has a different schema
  version="${latest_release}"
  version="${version#mimir-}"  # mimir
  version="${version#cmd/builder/v}"  # opentelemetry-collector
  version="${version#v}"  # Generic v- prefix
  # If the version already exists as a rock, exit here
  if [[ -d "$version" ]]; then echo "Folder $version already exists, nothing to do" && exit 0; fi
  # Create the folder for the new version and update the rockcraft.yaml
  cp -r "{{latest_version}}" "$version"
  latest_release="$latest_release" version="$version" yq -i \
    '.version = strenv(version) | .parts.{{rock_name}}["source-tag"] = strenv(latest_release)' \
    "./$version/rockcraft.yaml"
  # Automatically update build tools (go) from the upstream repository
  TMP_DIR="$(mktemp -d)"
  gh repo clone "{{source_repo}}" "$TMP_DIR/{{source_repo}}" -- --branch "$latest_release" --depth 1
  # If it's a Go project, update the Go version
  if [[ -f "$TMP_DIR/{{source_repo}}/go.mod" ]]; then
    go_snap_version="$(grep -Po '^go \K(\S+)' "$TMP_DIR/{{source_repo}}/go.mod" | sed -E 's/([0-9]+\.[0-9]+).*/\1/')"
    go_snap_version="$go_snap_version" yq -i \
      '(.parts.{{rock_name}}.build-snaps[] | select(test("^go/"))) = "go/"+strenv(go_snap_version)+"/candidate"' \
      "./$version/rockcraft.yaml"
  fi
  rm -rf "$TMP_DIR"
  echo "✓ Created rock for version $version"

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
  # Clone the oci-factory and push data to it
  gh repo sync --force observability-noctua-bot/oci-factory
  TMP_DIR="$(mktemp -d)"
  git clone https://github.com/observability-noctua-bot/oci-factory "$TMP_DIR/oci-factory"
  echo "✓ Cloned observability-noctua-bot/oci-factory"
  # Build the OCI Factory manifest
  echo "Building the OCI Factory manifest..."; echo
  uvx --from=git+https://github.com/lucabello/noctua noctua rock manifest \
    "$repository" \
    --commit="$(git rev-parse HEAD)" \
    --base=24.04 \
    --support="{{support}}" \
    --risk="{{risk}}" \
    --version="{{version}}" \
    | tee "$TMP_DIR/oci-factory/oci/{{rock_name}}/image.yaml"
  echo; echo "✓ OCI Factory manifest generated"
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
