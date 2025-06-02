**Date:** 2025-05-28<br/>
**Author:** Michael Dmitry(@michaeldmitry)  

## Context and Problem Statement

Pyroscope supports two deployment modes:

- **Monolithic mode** (`--target=all`): runs all components in a single process.
- **Microservices mode**: deployed as several processes, each one running a partition of the set of all existing roles.

Although the [official documentation](https://grafana.com/docs/pyroscope/latest/reference-pyroscope-architecture/deployment-modes/) does not mention it explicitly, Pyroscope **allows multiple targets to be specified** in a single process (e.g., `--target=ingester,distributor`). This allows running several components in a single process.

Unlike projects such as **Loki HA** or **Mimir**, the Pyroscope documentation does not specify a **recommended deployment mode** (e.g., Simple Scalable as in Loki HA).


The question is whether to follow: 
- [Tempo’s approach](https://github.com/canonical/tempo-worker-k8s-operator/blob/main/charmcraft.yaml#L55) (i.e. no meta roles except for `all`), only one role per process, or 
- Like Loki/Mimir, introduce some meta-roles (that WE own and define, and translate implicitly to sets of primitive roles, but are not captured in the upstream code or docs)


## Decision 

We will support the following deployment model in the Pyroscope charm:

- Support only one meta-role (i.e. `all`) which can be set by `juju config pyroscope-worker role-all=true`.
- Toggle individual roles by setting `juju config pyroscope-worker role-X=true|false` (e.g., `role-ingester=true`).
- Support a combination of roles by setting multiple `juju config pyroscope-worker role-X=true` config options (e.g., `juju config pyroscope-worker role-ingester=true role-distributor=true`).  
    → This would run the selected roles in the same worker process using `--target=X,Y`.


## Benefits

- We can independently scale out individual components if needed.
- Supports Pyroscope’s native ability to co-locate roles without enforcing any meta-roles that the upstream doesn't define.

## Disadvantages

- If each role runs on a dedicated worker, this increases the total number of deployed units. However, as we support a combination of roles, the user can choose their own combination to reduce the number of units.

## Alternatives considered

### Introduce meta-roles
Group roles into logical clusters like `read`, `write`, and `backend`.

### Disadvantages

- Upstream Pyroscope does not explicitly define such clusters.
- If upstream introduces official meta-roles later, we risk diverging from their structure.