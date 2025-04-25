# Juju-doctor Architecture
**Date:** 2025-02-05<br/>
**Authors:** @michaelthamm


## Context and Problem Statement
As a charmed solution user, I want to be able to validate deployments by running a set of atomic "probes". This set will indicate what "the right way" is for deploying the solution that this ruleset is designed for.

Also, I want to be able to source these probes both locally and from a remote (decentralized) source.

Finally, I want to be able to do this on a live environment, as well as on an environment I don't have access to, provided I have the output of a support archive such as (but not limited to) `sosreport`.

## The solution terminology
The environment validation tool we intend to create is called `juju-doctor`. The tool's main purpose is to run a configurable set of assertions/checks which we call `probes` against an environment description which in turn is the output (`artifact`) of other tools that we are not responsible for, such as `sosreport` or the output of commands such as `juju show-unit`/`kubectl describe`.

Juju-doctor will take this input (environment description + probes) and output an overall pass/fail as well as a configurably detailed overview of which tests failed, which passed, and any appropriate metadata such as possible solutions or troubleshooting info.

## Decision
A python program that understands declarative yaml and python probes. For python probes it attempts to run all of the following module level functions: `bundle()`, `status()`, `show_unit()` (a "pseudo-scriplet" approach).

## Alternatives

### (1) PyPi package probes runner fetching individual probes
- https://github.com/canonical/juju-doctor/

### (2) Go binary that runs scriptlet probes

- [Reference GH repo](https://github.com/michaeldmitry/juju-doctor-go/)
- This architecture is similar to (1) since probes exist in solution or charm remotes

Advantages:
- Uses an event-driven approach, meaning probes can be written for a specific event.

Disadvantages:
- starlark isn't python, so there isn't support for some Python modules that a probe author may need
  - e.g. `base64.b64decode(data)` or `lzma.decompress(decoded_data)` for Grafana dashboards


### (3) Snapped goss with gossfiles
- https://github.com/canonical/cos-lite-bundle/pull/123

### (4) Charm
Juju-doctor service running in a charm

Advantages:
- Native experience to the juju-ecosystem

Disadvantages:
- Needs Juju to validate on a solution archive
