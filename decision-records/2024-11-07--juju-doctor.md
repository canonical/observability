# Juju-doctor Architecture
**Date:** 2025-01-22<br/>
**Authors:** @michaelthamm


## Context and Problem Statement
Field and Support teams need a tool to validate Juju deployments, increasing hand-over confidence. Other tools in the support pipeline have their own niche and can be used in conjunction with `juju-doctor` or (potentially) as an input to the proposed `juju-doctor` tool.

For example, `sosreport` dumps useful Juju logs and environment context which `hotsos` then validates providing:
  - Supports application/subsystem plugins (Juju, k8s, LXD, MAAS, ...)
  - Addresses CVEs and Juju/System issues (Tracebacks in debug-log, or unattended upgrades enabled)

Alternatively, `juju-lint` is validating similar checks like `juju-doctor`:
  - Count of related subordinates
  - Relations

but lacks a modern implementation (its a DSL, only works for VM deployments).

`juju-doctor` could work in a similar way by generating/receiving a standardized dump (status.yaml, bundle.yaml, show-unit.yaml) and validating this deployment. The deployments variations (theoretically infinite) that `juju-doctor` needs to validate cannot be maintained solely by the Observability team. This introduces the decentralized probes (a unit-like test) architecture, where the tool can pull probes from remotes which are maintained by the stakeholders of the charm/deployment/probe

## Requirements
1. Probes are runnable without `juju-doctor` (piping from stdin)
2. Give information for each validation error (do not exit on first one)
3. Return code should be 0 (on success) and non-zero on failed validation
4. Validation errors and potential resolution steps go to stderr
5. Recommendation: place probes in root/probes within repos
6. The probe path relates to the validation message. Example:
``` bash
./probes/probe-1.py - FAILED:
./probes/probe-1.py - some message
./probes/probe-2.py - WARN:
./probes/probe-2.py - another message
```

## Decision
TBD

However, the final decision will likely be a combination of `(3)` and either `(1)` or `(2)`

``` mermaid
graph LR

production -->|field / support / customer | probes
test-env -->|SolQA| probes
probes -->|charm devs| charm[pebble checks, charm actions, ...]
```

## Considered options

### (1) Standardized input from support archive

Support often uses `sosreport` (we only care about the Juju plugin) for generating a support archive on a customer's machine. Most customers are familiar with this process and could be a great input (if standardized) for `juju-doctor` to validate.

### (2) Generate the archive as a precursor to validation

Assuming we want to have `juju-doctor` as a standalone tool (without requiring `sosreport`), then the tool itself generates the required files:

1. status.yaml
2. bundle.yaml
3. show-unit.yaml

This allows `juju-doctor` to determine which inputs (Juju commands) it needs to validate rather than creating all and only using some like in option `1`.

### (3) Pull probes from remotes in a decentralized fashion

Assumptions:
1. Probes exist within the charm repos (validating only that charm, in any deployment)
2. Probes exist within custom repos (i.e. cpe-deployments)

The user of `juju-doctor` is responsible for defining the remote probes required for the current validation and could define:
1. Multiple probe URLs (`--probe probe-1.py --probe probe-2.py`)
2. A directory of probes (run all inside)

`juju-doctor` would download these into a temp FS and execute them.

### (4) Subfolders per Juju artifact

The probes folder (in charm repo) will be structured so that we have 

```
/probes/status
/probes/bundle
/probes/show-unit
/probes/compound  # Inputs include juju-status.yaml, juju-bundle.yaml, and juju-show-unit.yaml
```

A compound probe cannot use stdin and instead uses argument flags. This could be a compelling argument for enforcing all checks to use flags instead of stdin for consistency.