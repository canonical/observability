# Observability

A repository to collect all the initiatives around Observability currently being
worked on at Canonical.

A list of all the active repositories maintained by the Observability team can be found using the [observability topic](https://github.com/search?q=topic%3Aobservability+org%3Acanonical+fork%3Atrue+archived%3Afalse&type=repositories).

Want to know more? See the [CharmHub topic page on Observability](https://charmhub.io/topics/canonical-observability-stack).

## GitHub Workflows

This repository holds all of our **reusable workflows**, in the `.github/workflows` folder; our other repositories implement their workflows by calling these. We follow two conventions for naming them:
* workflows starting with `_` are *“private”*, meaning they are used by other workflows and shouldn't be called directly;
* the name should loosely follow a `{scope}-{function}.yaml` schema, to make the folder easily searchable.

### Base Workflows

The **`issues.yaml`** workflow is used in all of our repositories to propagate GitHub issues to Jira; both opening and closing an issue will cause the related Jira issue to be (respectively) created or closed.

### Charm Workflows

| On PRs                                  | On main                                 | Periodically                 | Manually                   |
| --------------------------------------- | --------------------------------------- | ---------------------------- | -------------------------- |
| **`charm-pull-request.yaml`**           | **`charm-release.yaml`**                | **`charm-update-libs.yaml`** | **`charm-promote.yaml`**   |
| **`└── _charm-quality-checks.yaml`**    | **`├── _charm-quality-checks.yaml`**    |                              | `(charm-update-libs.yaml)` |
| `....├── _charm-codeql-analysis.yaml`   | `....├── _charm-codeql-analysis.yaml`   |                              |                            |
| `....├── _charm-static-analysis.yaml`   | `....├── _charm-static-analysis.yaml`   |                              |                            |
| `....├── _charm-linting.yaml`           | `....├── _charm-linting.yaml`           |                              |                            |
| `....├── _charm-tests-unit.yaml`        | `....├── _charm-tests-unit.yaml`        |                              |                            |
| `....├── _charm-tests-scenario.yaml`    | `....├── _charm-tests-scenario.yaml`    |                              |                            |
| `....└── _charm-tests-integration.yaml` | `....└── _charm-tests-integration.yaml` |                              |                            |
|                                         | **`└── _charm-release.yaml`**           |                              |                            |

Whenever a PR is opened to a charm repository, some quality checks are run:
* first check that the `CHARMHUB_TOKEN` secret is set on the repo, as it's needed by other actions;
* run the Canonical inclusive naming workflow;
* make sure charm libraries are updated and tag the PR accordingly with "Libraries: OK" or "Libraries: Out of Sync";
* run linting, analyses and tests to ensure the code quality.

After a PR is merged, the same quality checks are run on the main branch; when passing, the CI takes care of publishing any bumped charm library and releasing the charm to edge.

Periodically, CI checks whether the charm libraries are up-to-date; if not (i.e., another charm published an updated library), a PR is automatically opened to update them with the new version.

There's also a manual action to promote the charm (i.e., from `latest/edge` to `latest/beta`), making the process more user-friendly.

### Bundle Workflows
| On PRs                              | Periodically                |
| ------------------------------------| ----------------------------|
| **`bundle-pull-request.yaml`**      | **`bundle-release.yaml`**   |
| `├── _charm-codeql-analysis.yaml`   | `├── _bundle-release.yaml`  |
| `├── _charm-linting.yaml`           |
| `└── _charm-tests-integration.yaml` |

Whenever a PR is opened to a bundle repository, some quality checks are run:
* first check that the `CHARMHUB_TOKEN` secret is set on the repo, as it's needed by other actions;
* run the Canonical inclusive naming workflow.
* run linting, analyses and tests to ensure the code quality.

Periodically, integration matrix tests will run against a COS-related bundle and then, once the integration tests pass for any of the tracks: `edge`, `beta`, `candidate`, `stable`, a bundle gets released to each respective pinned track on Charmhub.

### Rock Workflows

| On PRs                          | On main                             | Periodically           | Manually                  |
| ------------------------------- | ----------------------------------- | ---------------------- | ------------------------- |
| **`_rock-pull-request.yaml`**   | **`rock-release-dev.yaml`**         | **`rock-update.yaml`** | `(rock-release-dev.yaml)` |
| **`└── _rock-build-test.yaml`** | **`rock-release-oci-factory.yaml`** |                        | `(rock-update.yaml)`      |

Our rocks are built in [oci-factory](https://github.com/canonical/oci-factory/), which covers:
* building and publishing the rocks to [DockerHub](https://hub.docker.com/u/ubuntu);
* tagging with semantic versions (e.g., `prometheus:{major}` pointing to the latest `prometheus:{major}.{minor}.{patch}`)
* periodically rebuilding rocks to pull any security fix.

These workflows make the repositories holding our rocks almost fully automated: whenever the upstream project releases a new version, a PR is opened automatically to add a rock for that specific version. Consequently, a workflow is run to make a quality check by trying to build the rock locally.

When the PR is merged, the rock is published to the GitHub Container Registry (GHCR) with a `:dev` tag. At the same time, a PR is opened to the **oci-factory** repo for the ROCKS Team to approve and merge, triggering the actual build process.

### Manual Workflows

| Manually                        |
| --------------------------------|
| **`_local-promote-train.yaml`** |

The [**Promote Train**](https://github.com/canonical/observability/actions/workflows/_local-promote-train.yaml) workflow allows to promote all the charms revisions to their next risk track. Specifically, if the tracks are open, the following promotions will be executed:
- `latest/candidate` --> `latest/stable`
- `latest/beta` --> `latest/candidate`
- `latest/edge` --> `latest/beta`

If the *dry-run* flag is selected, the promotion will simply be printed instead of being carried out.

## Meta Repo

This repo also contains the manifest (`manifest.yaml`) for syncing all repositories maintained by the observability team.
The script assumes that you want to place all repos in the parent folder of the `observability` repo. To use it, do the following:

```
# install the git-metarepo module
$ pip3 install metarepo

# sync the repos using the manifest
$ git meta sync
```
## Scripts
This repo also contains a `scripts` directory that could hold helper scripts for COS charms and bundles as `pip-installables`.

### `render-bundle`
This helper script is used by COS bundles as a `pip` package in a `tox.ini` file to render a `bundle.yaml.j2` template into a `bundle.yaml` file that can be deployed using `juju deploy ./bundle.yaml`.

### `freeze-bundle`
This script takes a `bundle.yaml` file and for each `application` along with its defined channel, it obtains the revision number for that application charm from Charmhub and updates `bundle.yaml` file with a pinned `revision` on each application. Currently, this script is used inside the `bundle-release.yaml` workflow.

### Contributing
To add similar helper scripts (e.g: `my_helper.py`) to be used as a `pip` package:

1. Add the script inside `scripts` directory.
2. In `scripts/pyproject.toml`, under `[project.scripts]`, add an entrypoint to your newly added script.
3. Increment `version` in `scripts/pyproject.toml`.
4. Add the script's description in `README.md`.