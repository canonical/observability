# Coordinated multirole workers
**Date:** 2024-06-13<br/>
**Authors:**

## Context and Problem Statement
We have charms for several grafana products, loki, mimir, and tempo, that all share the same design 
(with some variations): A single executable that, depending on the CLI args it is executed with, 
can be run in monolithic mode (i.e. a single process running all services) or microservices mode. 
What microservice mode means varies per product:

- **mimir**: each process runs an arbitrary subset of all the services, or certain predefined subsets
- **loki**: each process runs one of three predefined subsets of all the services
- **tempo**: each process runs exactly one service

We typically refer to services as `roles`, and the 'predefined subsets' of all existing roles 
for a product as `meta-roles`.

The set of required roles which are necessary for the deployment as a whole to be functional 
(we say, "consistent") vary per product. Certain roles can be optional, in that they aren't part of 
the minimal consistent deployment requirements.

We want to adopt a uniform design pattern for the architecture of all three charmed products.

## Decision

### Coordinator-worker pattern
Each charmed solution will consist of a single coordinator charm, and a generic worker charm that 
can be configured by the cloud admin to run any role (or meta-role) or combination thereof, 
depending on what the application supports.

The presence of a coordinator charm achieves several goals:
- offer a **single entrypoint** for all communication with the clustered application: it will 
  typically run an nginx instance to reverse-proxy all communication to the workers
- **cleaner juju topology**: 
  we expose a single facade for integrating with other charms: for example, we don't have to 
  relate each worker with s3: we only relate the coordinator, and the coordinator 
  forwards the appropriate config to the workers. 
- the coordinator charm is responsible for configuring and coordinating the workers, and can 
  **verify the consistency** of the cluster, that is, verify that the all required roles are 
  deployed. Without a coordinator, that'd have to be implemented as a distributed decision by 
  cross-relating all workers.


TODO: Pick one of marxist/bourgeois below

## Benefits


## Disadvantages



## Alternatives considered

### "marxist coordinator": Coordinator is a worker too

**pro:**
- better user story: you don't have to choose which charm to deploy, as there's only one working in two modes
- less charms to maintain
- easy migration path between a single-node and scaled setup
**con:**
- implementation complexity: the coordinator has to be able to decide when to run the worker as a monolith and when not to

### "bourgeois coordinator": Coordinator is not a worker
