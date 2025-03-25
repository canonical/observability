# Ruleset Probes
**Date:** 2025-02-05<br/>
**Authors:** @michaelthamm, @sed-i, @PietroPasotti


## Problem Statement
As a charmed solution user, I want to be able to verify that an environment (I deployed or that was delivered to me) is configured "the right way". The assertion should be configurable (without needing to be an expert on the system internals) in a programmatic way using some sort of environment validation tool.

Also, I want to be able to understand what "the right way" is according to those who have configured these assertions, and to contribute to that configuration by tuning the existing assertion parameters or contributing my own.

Finally, I want to be able to do this on a live environment, as well as on an environment I don't have access to, provided I have the output of a support archive aka `sosreport`.

## Context
In addition to pebble checks, charm actions, etc., a gap exists for a different kind of assertion. Charm devs should be able to quickly capture validation logic decoupled from charm code, i.e.
> probes are like a waiting room for checks to be absorbed by the charm.

## The solution terminology
A configurable set of assertions/checks called `probes` run against an environment description which in turn is the output of other tools that we are not responsible for, such as `sosreport` or the output of commands such as `juju show-unit/kubectl describe`.





```
Charms should have validation probes for their deployment in any context. The same probes should be equally applicable to live deployments and support archives (sosreport). A charm probe is a universal, external probe which makes assertions on established constructs (i.e. having a well-defined schema) such as Juju (status, bundle, show-unit) and Kubernetes (describe-pod).
```





## Alternatives
### (1) Runnable script
- A probe is a standalone, runnable script that expects data (in a well-defined schema) from stdin and returns 0 on success and non-zero value (and stderr) on failure.
- Each probe expects only 1 type of artifact (status, bundle, show-unit, etc.)
- Probes are external (outside of charm) and universal (applicable to arbitrary deployments)

Advantages
- Simple, easy to maintain, and narrowly scoped code

Disadvantages
- Cannot address cross-charm logic
  - E.g. A combination of show-unit outputs
  - but different show-unit outputs can be checked using the same probe
    - E.g. A probe in grafana-k8s can be used to assert on the show-unit of grafana-agent(-k8s)

### (2) Python module
- A probe is a standalone, python module (without a "main" guard) that expects data (in a well-defined schema) and raises an Exception on failure (with a message), otherwise success is assumed.
- Each probe can handle multiple supported artifacts (status, bundle, show-unit, etc.)
- Probes are external (outside of charm) and universal (applicable to arbitrary deployments)
- We can further categorize this into:
  - Charm probe; universal and applicable to a charm in any deployment scenario
  - Solution-level probe; depends on solution-specific artifact data (i.e. charm-a and charm-b must exist for the probe to be valid)

Advantages
- Simple, easy to maintain, and narrowly scoped code

Disadvantages
- Not standalone executable, i.e. require `juju-doctor` to develop and validate the probe

### (3) Declarative
- A probe is a shallowly nested YAML `ruleset` that expresses assertions about a deployment using a bespoke DSL
- Assertions take place outside of the charm and are universal
- Supports multiple `probe` types:
  - Another ruleset; ruleset chaining (should guard against circular dependency)
  - Python probe; alternatives `(1)` or `(2)`
  - Built-in probe; universal for any deployment, e.g. `apps/has-relation`, `apps/has-subordinate`, `apps/unit-limit`
  - Ad-hoc probe; non-standard in-line Python script

Advantages
- Non-technical authors can easily understand the deployment abstraction
- Easy to adjust a deployment feature (expects 2 units instead of 1)

Disadvantages
- Learn a new language

### (4) Scriptlets
- A charm probe is a StarLark "scriptlet" which is called by an event-driven framework
- The well-defined constructs are passed as event payloads

Advantages
- Can conveniently pass multiple constructs to the same probe
- Starlark is sandboxed, adding security guarantees

Disadvantages
- Probes are not standalone
- Starlark does not offer the flexibility of Python

### (5) Goss file
- A charm probe is a gossfile which can use GJSON matchers to parse constructs JSON format

Advantages
- Efficient parsing of JSON
- Prometheus metrics endpoint

Disadvantages
- Cannot address cross-charm logic without multiple `juju ssh` commands
- Essentially a dumb wrapper around the `command` resource
- Learn a new language

### (6) Justfile
- A charm probe is a Justfile allowing you to assert in any language

Advantages
- Probes support multiple languages

Disadvantages
- Another language to learn

## Decision
The only way to write probes is with `(1)` with Python probes limited to `(2)`. 
