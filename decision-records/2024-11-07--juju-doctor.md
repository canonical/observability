# Juju-doctor Architecture
**Date:** 2025-02-05<br/>
**Authors:** @michaelthamm


## Context and Problem Statement
Juju admins need a tool to validate deployments, increasing hand-over confidence.

## Decision
TBD

## Alternatives

### (1) PyPi package probes runner fetching individual probes
- https://github.com/canonical/juju-doctor/

### (2) Go binary that runs scriptlet probes
- This architecture is the similar to (1) since probes exist in solution or charm remotes

### (3) Snapped goss with gossfiles
- https://github.com/canonical/cos-lite-bundle/pull/123


## Additional context

### (1a)
`juju-doctor` input can be:
- live model, generating the constructs itself (status, bundle, show-unit) prior to validation
- file argument
- solution archive

### (1b)
Hierarchy and grouping for probes relating to the validation message.
Example:
``` bash
./probes/probe-1.py - FAILED:
./probes/probe-1.py - some message
./probes/probe-2.py - WARN:
./probes/probe-2.py - another message
```

### (1c)
Terraform notation for probe paths:
- `file://path-to-probe/probe.py`
- `github://org/repo//probes/probe.py?my-branch`
  - `//` signifies a sub-dir in the repo
  - `?` signifies a branch, default to main

### (1d)
The probes folder (in charm repo) will be structured like:
```
/probes/status
/probes/bundle
/probes/show-unit
/probes/compound  # Input from multiple constructs
```
A compound probe cannot use stdin and instead uses argument flags. This could be a compelling argument for enforcing all checks to use flags instead of stdin for consistency.

### (1e)
`juju-doctor` downloads probes into a temp FS and executes them.