# Shared URLs between COS-Lite components and external charms
**Date:** 2024-07-16<br/>
**Authors:** @Abuelodelanada, @sed-i


## Context and Problem Statement
The workload of many charms is a server, that other charmed workloads need to reach.
Typically, the server URL is "announced" over relation data, but we have different URLs "types" we could announce:
```
{HTTP / HTTPS} {internal / ingress} {IP / FQDN}
```
Which URL(s) should we announce to other charms?

## Decision
- Announce no more than one server URL on the same relation interface. I.e. do not announce both internal and external URLs for the same server on the same relation interface.
- If TLS is enabled, then only announce the HTTPS.
- If ingress is available, then the ingress (external) URL; otherwise: FQDN (internal). Exceptions:
  - `ingress` relation: the loadbalanced server URLs will use k8s fqdn address.
  - `tls-certificates` relation: only ingress charms will render a CSR with their external url; all other charms will render a CSR with k8s fqdn address.
  - Alertmanager's peer relation: gossip ring will use k8s fqdn address.

## Benefits
- Charm code does not need to concern itself whether a given relation is in-model or cross-model.

## Disadvantages
- Ingress (traefik) becomes a single point of failure for in-model traffic.
- All charms need to trust the CA that signed the ingress. If the trust chain includes a root CA and the charm has ca-certificates installed, then this is a non-issue.
  Otherwise may need to have a [`receive-ca-cert`](https://github.com/canonical/certificate-transfer-interface/) relation.

## Alternatives considered
- Annouce the internal URL for in-model relations and the external URL for cross-model relations. Since a charm [cannot always determine if a relation is cross model](https://github.com/canonical/cos-lib/pull/30),
  this alternative was abandoned.

## History
During the COS-Lite building process there was a lot of back and forth on the shared URLs (metrics endpoints, datasources endpoints, etc) between COS-Lite components. 

For instance, the very first approach was to use intra-model IPs to build the endpoints that Prometheus was going to scrape. Soon we realised not always the internal IPs were available at the moment the endpoint was built, and that IP changes across an upgrade..

Using intra-model FQDNs emerged as a second approach as the names are predictable at any moment. 

After implementing this second approach, Traefik charm became a reality. The decision was then to use ingress-provided address to build URLs (metrics endpoints, datasource endpoints, etc) if the relation between Traefik and the charm was established, if not use FQDNs.
