**Date:** 2026-10-14<br/>
**Author:** Luca Bello (@lucabello)

## Context and Problem Statement

We're moving charm integration tests to feature files ([pytest-bdd](https://pytest-bdd.readthedocs.io/)). Many behaviours look the same across our charms: TLS, ingress, sending logs to Loki, metrics, dashboards, and so on. That makes it tempting to write those feature files and their step definitions (the `@given` / `@when` / `@then` functions) once, and reuse them in every charm.

There are three ways to share them:

1. **A package with features and steps**: a pip-installable package ships both the `.feature` files and their step definitions.
2. **Blueprint sync**: the same files live in `blueprints/charms/` in this repo, and `just refresh` copies them into each charm.
3. **A package with steps only**: a package ships only the step definitions, and each charm writes its own feature files with them.

The other option is to share neither, and let each charm own both its feature files and its steps.

To decide, we built all three ways of sharing on `alertmanager-k8s`, covering TLS and log forwarding. All three ran green against a real Kubernetes controller. So the question isn't whether sharing *can* work; it's whether it's worth it.

## Decision: each charm owns its feature files and its step definitions

We don't share feature files or step definitions between charm repositories. Each charm writes the scenarios for its own behaviour, in its own words, and implements the steps next to them.

What we do share:

- **API clients** for our workloads. Plain Python with no Gherkin, in [`observability-clients`](https://github.com/canonical/observability-libs/tree/main/observability-clients), as today.
- **Conventions**: how to word steps, where step modules live, and so on.
- **Examples to copy once** when a charm adopts feature files. They are never kept in sync.

## Benefits

### Feature files describe the charm

A shared feature file can't name the charm it's testing. In the shared-features prototype it had to read like this:

```gherkin
Scenario: The workload API is served over HTTPS
  Given the charm is deployed
  And a certificates provider is deployed
  When the charm is integrated with the certificates provider
  Then the workload API is served over HTTPS
```

A shared file also can't be extended in place. Alertmanager's own TLS scenario (still serving HTTPS after a refresh) had to go into a second, local feature file. That left one behaviour split across two `Feature: TLS…` files, one of them in `site-packages`. When the charm owns the file, both scenarios live together and talk about Alertmanager.

### We already tried sharing feature files, and undid it

The solution tests in `observability-stack` started with one shared `features/` directory, using `@cos` / `@cos-lite` tags to pick scenarios. They then [moved to one folder per solution](https://github.com/canonical/observability-stack/commit/16fe49b3106864d5b269670fa627309da4822a9f), because "no scenario carried both tags, so the shared features/ plus @cos/@cos-lite tagging only added indirection".

Their [README](https://github.com/canonical/observability-stack/blob/3c0b48170b0d2920b58c5721de0842bb8a0e82e4/tests/solution/README.md?plain=1#L60-L62) now says: "give each its own copy naming its own workload rather than sharing a file".

### Similar behaviours aren't checked the same way

"Metrics reach the backend" sounds like one step, but it isn't. In `observability-stack`, [Prometheus and Mimir have separate steps](https://github.com/canonical/observability-stack/blob/3c0b48170b0d2920b58c5721de0842bb8a0e82e4/tests/solution/steps/telemetry.py#L10-L35): Prometheus retries for two minutes because scraping is periodic, while Mimir doesn't retry at all.

The prototypes kept running into the same problem:

- **Steps need to know a lot about the charm.** To share feature files, the steps need a description of the charm under test. For just two features that already meant the app name, the charm path, its resources, the workload port and `trust`. Every new feature adds to that list.
- **Endpoint names can't always be guessed.** Alertmanager has two endpoints using the `tracing` interface ([`tracing` and `charm-tracing`](https://github.com/canonical/alertmanager-k8s-operator/blob/0ffba9a3dff6a03134c994c493e45888681d9a94/charmcraft.yaml#L127-L150)). It also requires both `certificates` and `receive-ca-cert`, and `self-signed-certificates` provides a match for each. So a plain `juju integrate alertmanager self-signed-certificates` matches two relations.
- **Coordinated charms don't fit a single "charm under test".** Pyroscope is a coordinator plus workers, so "deploy the charm" means deploying several apps. "Logs from the charm" is also ambiguous, because the logs come from the worker app, not the coordinator.

Each shared step would have to cover all these cases. A step owned by the charm only needs to handle that charm.

### You can see where every step comes from

In the steps-only prototype, Alertmanager's `tls.feature` used sentences from three places: `observability_steps.tls`, `observability_steps.logs`, and the local `steps/alertmanager.py`. Nothing in the feature file tells you which sentence comes from where. To find out, you need to read the `pytest_plugins` list and then go digging through the installed package.

It gets worse with clashes. If two shared modules accept the same sentence, pytest-bdd just [picks one of them without telling you](https://github.com/pytest-dev/pytest-bdd/blob/9.0.0/src/pytest_bdd/scenario.py#L133-L163), and which one it picks doesn't depend on the order of `pytest_plugins`. We tested that.

When every step lives in the charm's own `tests/integration/steps/`, finding a step is just a grep.

### It's about the same amount of code as today

Each charm already writes these checks itself. Today, at least five repositories (alertmanager, istio-ingress, parca-scrape-target, pyroscope and observability-stack) each have their own code for fetching the CA certificate in TLS tests. About ten charm repositories have their own Loki or `juju_application` queries.

Writing those checks as local feature files and steps doesn't add duplication; it reshapes the duplication we already have. In Alertmanager:

- TLS and log forwarding take 149 lines today (`test_tls_web.py` and `test_logging.py`).
- With fully local feature files and steps they take about 210 lines: 82 for feature files, wiring and the steps for deploying and refreshing Alertmanager, and about 125 for the TLS, Loki and Juju steps.
- The new version also checks more: every unit, the certificate hostname, and that TLS survives a refresh.
- The roughly 40 lines of "deploy if missing / integrate if not related" helpers are written once per charm, and every later feature reuses them.

## Disadvantages

- **Bugs get copied, and so do their fixes.** A bug in a step that was copied around has to be fixed in each copy. We already have an example. Alertmanager's TLS tests build the expected certificate hostname from `juju.model`, which turns into `controller:model` when you pass `--juju-controller`. That bug is copied three times in one repo ([1](https://github.com/canonical/alertmanager-k8s-operator/blob/0ffba9a3dff6a03134c994c493e45888681d9a94/tests/integration/test_tls_web.py#L56), [2](https://github.com/canonical/alertmanager-k8s-operator/blob/0ffba9a3dff6a03134c994c493e45888681d9a94/tests/integration/test_tls_web.py#L64), [3](https://github.com/canonical/alertmanager-k8s-operator/blob/0ffba9a3dff6a03134c994c493e45888681d9a94/tests/integration/test_workload_tracing_tls.py#L86)).
- **Charms can drift apart.** "Supports TLS" may end up meaning slightly different things in different charms. Conventions and the copy-once examples help, but nothing enforces them.
- **No single list of feature files.** "Which charms support feature X?" has no ready answer. A tagging convention for feature files could answer it later, without sharing any code.
- **More work for each new charm.** The first feature files take more effort than installing a package would. Copying the examples covers most of it.

## Alternatives considered

### A package with features and steps

This works. The package exposes a `feature("tls.feature")` helper that returns an absolute path into the installed package. That's needed because pytest-bdd only resolves relative paths from the test module or from `bdd_features_base_dir`, and [neither can point into `site-packages`](https://github.com/pytest-dev/pytest-bdd/blob/9.0.0/src/pytest_bdd/scenario.py#L396-L402). A charm can override any shipped step by defining it again in its own `conftest.py` or test module.

We rejected it for the reasons under *Benefits*: feature files that can't name the charm, behaviours split across two files, and a list of things the steps need to know about the charm that grows with every feature. It also means a new public API (the feature files and that charm description) to version and keep stable.

### Blueprint sync

This also works, using an extended `just refresh` that mirrors a directory from this repo into the charm. It shares every problem of the package, and adds a few of its own:

- **No real versioning.** You can only pin a git ref, and a refresh pulls everything in the blueprint at once. Alertmanager's `charms.just` is already behind the blueprint today. Refreshing to pick up test files also dragged in unrelated recipes.
- **Missing dependencies.** Each charm has to add the copied code's dependencies itself, such as `observability-clients`.
- **Noisy diffs.** The copied code lands in every charm PR: the shared directory alone was +237 lines in Alertmanager. The whole package-based change was +63.
- **Local edits get overwritten.** Nothing stops someone from editing the copied files, and the next refresh silently overwrites those edits.

### A package with steps only

This is the most appealing way to share. Steps put the app name in the sentence (`the "alertmanager" application serves HTTPS on port 9093`), so the charm doesn't have to describe itself, and feature files stay in the charm.

We rejected it because:

- **It's harder to work on a charm.** Nothing in the feature file shows which steps are local and which come from the package.
- **Clashes are silent.** If two modules accept the same sentence, pytest-bdd picks one without any warning.
- **There's little to share.** Steps that are genuinely the same for every charm are a small set, and each is only a few dozen lines. The part that's really shared, talking to the workload APIs, is already in `observability-clients`.
