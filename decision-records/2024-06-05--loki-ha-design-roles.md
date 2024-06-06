**Date:** 2024-06-05<br/>
**Author:** Luca Bello (@lucabello)  

## Context and Problem Statement

The Loki HA deployment can be carried out in two different modes, according to the [official documentation](https://grafana.com/docs/loki/latest/get-started/deployment-modes/):
* **Simple Scalable**, with three meta-components *read*, *write* and *backend* (and *all*);
* **Microservices mode**, with the full set of components.

Microservices mode is closer to what we currently do for the Mimir HA solution. However, there's a few issues with replicating that for Loki HA:
1. some components that are [listed](https://grafana.com/docs/loki/latest/get-started/deployment-modes/#microservices-mode) are not [documented](https://grafana.com/docs/loki/latest/get-started/components/);
2. there's no *Nginx* configuration in the official Helm charts;
3. the [Loki HTTP API documentation](https://grafana.com/docs/loki/latest/reference/loki-http-api/) might not be complete (because some roles are missing entirely).

Choosing to use only the documented components could cause us to stumble into undocumented issues (e.g., a required undocumented role missing from our deployment). **Simple Scalable** is documented to use *read*, *write* and *backend* instead of explicitly deploying components (such as *querier*, *distributor*, etc.).

The problem revolves around which role setup we should go for

## Decision 

We will follow the recommended deployment mode for **Simple Scalable**, and start with only allowing the roles: *read*, *write*, *backend* and *all*.

## Benefits

* Simpler Nginx configuration, that also matches the one in the official Helm chart
* Relatively easy to add new roles with finer granularity in the future

## Disadvantages

* The user cannot scale individual components independently *if they are in the same meta-role* (e.g, distributor and ingester)

## Alternatives considered

* Microservices mode, disqualified due to it being not fully documented and more complex (and at a small gain, since we don't foresee this to be a wanted feature)
