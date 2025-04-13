# Juju-doctor Architecture
**Date:** 2025-02-05<br/>
**Authors:** @michaelthamm


## Context and Problem Statement
As a charmed solution user, I want to be able to validate deployments by running a set of atomic "probes". This set will indicate what "the right way" is for deploying the solution that this ruleset is designed for.

Also, I want to be able to source these probes both locally and from a remote (decentralized) source.

Finally, I want to be able to do this on a live environment, as well as on an environment I don't have access to, provided I have the output of a support archive aka `sosreport`.

## The solution terminology
The environment validation tool we intend to create is called `juju-doctor`. The tool's main purpose is to run a configurable set of assertions/checks which we call `probes` against an environment description which in turn is the output (`artifact`) of other tools that we are not responsible for, such as `sosreport` or the output of commands such as `juju show-unit`/`kubectl describe`.

Juju-doctor will take this input (environment description + probes) and output an overall pass/fail as well as a configurably detailed overview of which tests failed, which passed, and any appropriate metadata such as possible solutions or troubleshooting info.

## Decision
TBD

## Alternatives

### (1) PyPi package probes runner fetching individual probes
- https://github.com/canonical/juju-doctor/

### (2) Go binary that runs scriptlet probes
- This architecture is the similar to (1) since probes exist in solution or charm remotes

### (3) Snapped goss with gossfiles
- https://github.com/canonical/cos-lite-bundle/pull/123

### (4) Charm
Juju-doctor service running in a charm

Advantage:
- Native experience to the juju-ecosystem

Disadvantages
- Needs Juju to validate on a solution archive



## Additional context

### (1a) ✅ Input
`juju-doctor` input can be:
- live model, generating the constructs itself (status, bundle, show-unit) prior to validation
- file argument(s)
- solution archive

### (1b) ❓️ Formatting, filtering, and grouping output
Hierarchy and grouping for probes relating to the validation message.
Example:
``` bash
artifact.probe.py - status/bundle/show_unit
parent.probe-1.py - I am a node in the parent tree 
       probe-2.py - I am a node in the parent tree
status.probe-2.py - pass/fail
```

### (1c) ✅ Terraform notation for probe paths
- `file://path-to-probe/probe.py`
- `github://org/repo//probes/probe.py?my-branch`
  - `//` signifies a sub-dir in the repo
  - `?` signifies a branch, default to main

### (1d) ❌ The probes folder (in charm repo) structure:
```
/probes/status
/probes/bundle
/probes/show-unit
/probes/compound  # Input from multiple constructs
```
A compound probe cannot use stdin and instead uses argument flags. This could be a compelling argument for enforcing all checks to use flags instead of stdin for consistency.

### (1e) ✅ Download probes into a temp FS and executes
- Using [fsspec](https://filesystem-spec.readthedocs.io/)