# Coordinated multirole workers
**Date:** 2024-06-13<br/>
**Authors:**

## Context and Problem Statement
We have charms for several grafana products that all share the same design:
A single executable that, depending on the role(s) we set in a CLI arg, can be
run in monolithic mode or microservices mode. A single process can have any
combination of roles, but for a working deployment we need to make sure all the
necessary roles are in fact running.

This single-binary multirole design is common to loki, mimir, and tempo.

We want a consistent design pattern to share among all charms that operate a
multirole worker.

## Decision


## Benefits


## Disadvantages


## Alternatives considered
