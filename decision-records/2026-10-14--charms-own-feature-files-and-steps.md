**Date:** 2026-10-14<br/>
**Author:** Luca Bello (@lucabello)

## Context and Problem Statement

We're moving charm integration tests to feature files ([pytest-bdd](https://pytest-bdd.readthedocs.io/)). Many behaviours look the same across our charms: TLS, ingress, sending logs to Loki, metrics, dashboards, and so on. That makes it tempting to write those feature files and their step definitions (the `@given` / `@when` / `@then` functions) once, and reuse them in every charm.

We thought of three ways to share them:

1. **A package with features and steps**: a pip-installable package ships both the `.feature` files and their step definitions.
2. **Blueprint sync**: the same files live in `blueprints/charms/` in this repo, and `just refresh` copies them into each charm.
3. **A package with steps only**: a package ships only the step definitions, and each charm writes its own feature files with them.

The other option is to share neither, and let each charm own both its feature files and its steps.

To decide, I built all three ways of sharing on `alertmanager-k8s`, covering TLS and log forwarding. This ADR presents my analysis and conclusions.

## Decision: each charm owns its feature files and its step definitions

We don't share feature files or step definitions between charm repositories. Each charm writes the scenarios for its own behaviour, in its own words, and implements the steps next to them.

What we do share:

- API clients for our workloads, in [`observability-clients`](https://github.com/canonical/observability-libs/tree/main/observability-clients), as today.
- Conventions: how to word steps, where step modules live, and so on.
- Examples that a charm copies once when it adopts feature files. We don't keep them in sync.

## Benefits

### Not sharing worked better for the solution tests

While writing the solution tests in `observability-stack`, we learned that not sharing features between solutions was better. The tests started with one shared `features/` directory, using `@cos` / `@cos-lite` tags to pick the scenarios for each solution. In [#491](https://github.com/canonical/observability-stack/pull/491) we moved to one folder per solution instead, for two reasons:

- No scenario carried both tags, so the shared directory and the tags only added indirection.
- With all of a solution's features in its own folder, it's obvious where to look. That's why we [duplicated even `smoke.feature`](https://github.com/canonical/observability-stack/pull/491#discussion_r4155017340), which was identical for both solutions.

### Similar behaviours aren't checked the same way

Behaviours that read the same in a feature file can need different checks. In `observability-stack`, "metrics reach the backend" has [separate steps for Prometheus and Mimir](https://github.com/canonical/observability-stack/blob/3c0b48170b0d2920b58c5721de0842bb8a0e82e4/tests/solution/steps/telemetry.py#L10-L35): Prometheus retries for two minutes because scraping is periodic, while Mimir doesn't retry at all.

We'd face the same problem reusing self-monitoring steps across charms, since the metrics backend in a test can be either Prometheus or Mimir.

### You can see where every step comes from

In the steps-only prototype, Alertmanager's `tls.feature` used sentences from three places: `observability_steps.tls`, `observability_steps.logs`, and the local `steps/alertmanager.py`. Nothing in the feature file tells you which sentence comes from where. To find out, you need to read the `pytest_plugins` list and then go digging through the installed package.

It gets worse with clashes. If two shared modules accept the same sentence, pytest-bdd just [picks one of them without telling you](https://github.com/pytest-dev/pytest-bdd/blob/9.0.0/src/pytest_bdd/scenario.py#L133-L163), and which one it picks doesn't depend on the order of `pytest_plugins`. I tested that.

When every step lives in the charm's own `tests/integration/steps/`, finding a step is just a grep.

### The duplication is similar to today's

Behaviours that every charm has (or should have), like self-monitoring, are already tested separately in each charm's integration tests. Keeping feature files and steps in each charm keeps the duplication in the same order of magnitude as today.

## Disadvantages

- We lose reusability: steps for behaviours that look alike are written again in each charm, which adds some duplication.
- Charms can drift apart, both in how we implement steps and in the language of our feature files.

## Alternatives considered

All three are rejected because of the benefits of not sharing described above.

### A package with features and steps

A pip-installable package (e.g. in `observability-libs`) ships the `.feature` files and their step definitions. Charms load the shipped feature files by absolute path and register the steps as pytest plugins. A charm can override any shipped step by defining it again in its own `conftest.py` or test module.

### Blueprint sync

The same feature files and steps live in `blueprints/charms/`, and `just refresh` mirrors them into each charm's `tests/integration/`.

### A package with steps only

A pip-installable package ships only step definitions, and each charm writes its own feature files with them. Steps put the app name in the sentence (`the "alertmanager" application serves HTTPS on port 9093`), so the charm doesn't have to describe itself to the package.
