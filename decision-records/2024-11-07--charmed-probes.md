# Charmed Probes Architecture
**Date:** 2025-02-05<br/>
**Authors:** @michaelthamm


## Context and Problem Statement
In addition to pebble checks, charm actions, etc., a gap exists for a different kind of validation check. Juju admins need to have a way to validate a deployment without knowing much about the system internals. In addition, they should easily be able to contribute new validation checks to charms. Also, charm devs should be able to quickly capture validation logic decoupled from charm code (probes are like a waiting room for checks to be absorbed by the charm).

Charms should have validation probes for their deployment in any context. The same probes should be equally applicable to live deployments and support archives (sosreport). A charmed probe is a universal, external probe which makes assertions on established constructs (i.e. having a well-defined schema) such as Juju (status, bundle, show-unit) and Kubernetes (describe-pod).

## Alternatives
### (1) Runnable script
- A charm probe is a standalone, runnable script that expects data (in a well-defined schema) from stdin and returns 0 on success and non-zero value (and stderr) on failure.
- Each probe expects only 1 type of construct (status, bundle, show-unit, etc.)
- Probes are external (outside of charm) and universal (applicable to arbitrary deployments)

Advantages
- Simple, easy to maintain, and narrowly scoped code

Disadvantages
- Cannot address cross-charm logic
  - E.g. A combination of show-unit outputs
  - but different show-unit outputs can be checked using the same probe
    - E.g. A probe in grafana-k8s can be used to assert on the show-unit of grafana-agent(-k8s)

### (2) Declarative
- A charm probe is a shallowly nested YAML that expresses assertions about a deployment using a bespoke DSL
- Assertions take place outside of the charm and are universal

Advantages
- Non-technical authors can easily understand the deployment abstraction
- Easy to adjust a deployment feature (expects 2 units instead of 1)

Disadvantages
- Learn a new language

### (3) Scriptlets
- A charm probe is a StarLark "scriptlet" which is called by an event-driven framework
- The well-defined constructs are passed as event payloads

Advantages
- Can conveniently pass multiple constructs to the same probe

Disadvantages
- Probes are not standalone

### (4) Goss file
- A charm probe is a gossfile which can use GJSON matchers to parse constructs JSON format

Advantages
- Efficient parsing of JSON
- Prometheus metrics endpoint

Disadvantages
- Cannot address cross-charm logic without multiple `juju ssh` commands
- Essentially a dumb wrapper around the `command` resource
- Learn a new language

### (5) Justfile
- A charm probe is a Justfile allowing you to assert in any language

Advantages
- Probes support multiple languages

Disadvantages
- Its not Make


## Decision
A proof of concept with `(1)` and the final implementation will be a combination of `(1)` and `(2)`. 
