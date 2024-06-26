# Extra tempo receivers
**Date:** 2024-06-25<br/>
**Authors:** @PietroPasotti, @mmkay, @michaeldmitry

## Context and Problem Statement
Charms seeking to push traces to Tempo will relate to the Tempo charm over a `tracing` relation. [The protocol](https://github.com/canonical/charm-relation-interfaces/tree/main/interfaces/tracing/v2) specifies that the requirer charm needs to request a list of the tracing protocols it intends to use to send spans to Tempo (e.g: `otlp_http`, `jaeger`). Then, as a response, the provider Tempo will share for each requested protocol (so long as it supports it), an endpoint to which workloads/charms can push traces.
Tempo only enables receivers for the protocols it actually needs to satisfy all incoming requests. Therefore, if a user wants to send traces to Tempo over a protocol that no charm is currently requesting via the `tracing` interface, there needs to be a way to configure the Tempo charm to enable that receiver regardless of whether there is a `tracing` integration asking for it the regular way. Given that, this would support our decision of allowing uncharmed applications to send traces as well.
The choice now is: how do we allow the end user of the Tempo charm to specify which subset of the possible tracing protocols to always enable, regardless of integrations? 

## Decision

### Config option for each receiver
#### Syntax:
The decision is, for each protocol Tempo supports, to expose a juju config option on the tempo-coordinator charm to force-enable it. 
Thus for each supported protocol `X` there will be an `always_enable_X:bool` config option.
#### Semantics:
The coordinator charm will collect all protocols that are configured to "always_enable" and add those to the set of protocols that are requested through active tracing relations from charmed workloads.
```
juju config tempo enable_zipkin=True
juju config tempo enable_otlp_grpc=True
juju config tempo enable_otlp_http=True
```
### Benefits
- Minimizes the chances of user errors as Juju handles all input parsing (which means we don't have to worry about typos, user asking for unsupported/nonexistent protocols, duplicates...).
- We don't have to worry about storing the extra receivers somewhere, as config is persisted in Juju.
- Consistency with [the enum pattern implemented for mimir roles](https://github.com/canonical/mimir-worker-k8s-operator/blob/main/config.yaml).
- Simplicity in UX.
### Disadvantages
- Maintenance: config options depend on the currently supported protocols, there is a chance that future versions of tempo may add/remove some and force the charm's API to change in non-backwards-compatible ways. Hopefully, however, the set of supported protocols will only shrink as the industry converges towards a smaller set of standards (otlp?)
- Ugliness: having individual flags for each enum member to tag a subset of it is not a very neat design, but ATM it's all that Juju offers us. See [the charmhub page for mimir-worker](https://charmhub.io/mimir-worker-k8s/configuration) to see what it looks like in practice. The UX is also not super: you can only enable/disable one at a time.

## Alternatives considered

### Comma separated config
Have a single config option to provide a comma-separated list of roles.

```
juju config tempo receivers=oltp_grpc,otlp_http
```
### Benefits
- We don't have to worry about storing the extra receivers somewhere, as config is persisted in Juju.
### Disadvantages
- Prone to user errors (notice in the example "oltp_grpc" is misspelled).
- Poor UX.

### Actions
Set extra receivers using an action to enable a specific extra receiver.
```
juju run tempo/0 enable-receiver otlp_grpc
```
### Benefits
- Minimizes the chances of user errors
### Disadvantages
- We have to store the extra receivers somewhere (e.g: peer relation data).
- Actions run on units, not apps. Hard to manage user expectations as to what'd happen if you run it on a follower unit vs. the leader.