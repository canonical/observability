# Observability

A repository to collect all of the initiatives around Observability currently being 
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
| `....├── _charm-linting.yaml`           | `....├── _charm-linting.yaml`           |                              |                            |
| `....├── _charm-unit-tests.yaml`        | `....├── _charm-unit-tests.yaml`        |                              |                            |
| `....├── _charm-scenario-tests.yaml`    | `....├── _charm-scenario-tests.yaml`    |                              |                            |
| `....└── _charm-integration-tests.yaml` | `....└── _charm-integration-tests.yaml` |                              |                            |
|                                         | **`└── _charm-release.yaml`**           |                              |                            |

Whenever a PR is opened to a charm repository, some quality checks are run:
* first check that the `CHARMHUB_TOKEN` secret is set on the repo, as it's needed by other actions;
* run the Canonical inclusive naming workflow;
* make sure charm libraries are updated and tag the PR accordingly with "Libraries: OK" or "Libraries: Out of Sync";
* run linting, analyses and tests to ensure the code quality.

After a PR is merged, the same quality checks are run on the main branch; when passing, the CI takes care of publishing any bumped charm library and releasing the charm to edge.

Periodically, CI checks whether the charm libraries are up-to-date; if not (i.e., another charm published an updated library), a PR is automatically opened to update them with the new version.

There's also a manual action to promote the charm (i.e., from `latest/edge` to `latest/beta`), making the process more user-friendly.

### ROCK Workflows

| On PRs                          | On main                             | Periodically           | Manually                  |
| ------------------------------- | ----------------------------------- | ---------------------- | ------------------------- |
| **`_rock-pull-request.yaml`**   | **`rock-release-dev.yaml`**         | **`rock-update.yaml`** | `(rock-release-dev.yaml)` |
| **`└── _rock-build-test.yaml`** | **`rock-release-oci-factory.yaml`** |                        | `(rock-update.yaml)`      |

Our ROCKs are built in [oci-factory](https://github.com/canonical/oci-factory/), which covers:
* building and publishing the ROCKS to [DockerHub](https://hub.docker.com/u/ubuntu);
* tagging with semantic versions (e.g., `prometheus:{major}` pointing to the latest `prometheus:{major}.{minor}.{patch}`)
* periodically rebuilding ROCKs to pull any security fix.

These workflows make the repositories holding our ROCKs almost fully automated: whenever the upstream project releases a new version, a PR is opened automatically to add a ROCK for that specific version. Consequently, a workflow is run to make a quality check by trying to build the ROCK locally.

When the PR is merged, the ROCK is published to the GitHub Container Registry (GHCR) with a `:dev` tag. At the same time, a PR is opened to the **oci-factory** repo for the ROCKs team to approve and merge, triggering the actual build process.


## Meta Repo

This repo also contains the manifest (`manifest.yaml`) for syncing all repositories maintained by the observability team.
The script assumes that you want to place all repos in the parent folder of the `observability` repo. To use it, do the following:

```
# install the git-metarepo module
$ pip3 install metarepo

# sync the repos using the manifest
$ git meta sync
```
