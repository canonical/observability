# Extra tempo receivers
**Date:** 2024-06-25<br/>
**Authors:** @PietroPasotti, @mmkay, @michaeldmitry

## Context and Problem Statement
charms seeking to push traces to tempo relate to tempo charm over tracing relation. Those charms need to specify a list of tracing protocols it intends to send tracing with (e.g: otlp_http). Then, as a response, tempo provides an endpoint corresponding to each protocol requested where workloads/charms can push traces.
However, that is only applicable to **charmed workloads**. For uncharmed applications, integration is through grafana agent, as specified in https://discourse.charmhub.io/t/how-to-integrate-cos-lite-with-uncharmed-applications/12005.
Since requesting tracing endpoints from tempo charm is done through charm relations, there needs to be another way to tell tempo to provide an endpoint with a specific protocol to the uncharmed application that wishes to push traces to tempo even when there are no relations requesting that protocol.

## Decision

### Config option for each receiver
Have multiple config options to enable a receiver for each protocol we support for tempo charm. These **extra** receivers will tell tempo to provide endpoints for those protocols and will be unioned with those coming from tracing relations so that uncharmed applications can send traces using any supported protocol without depending on relation data.
```
juju config tempo enable_zipkin=True
juju config tempo enable_kafka=True
juju config tempo enable_opencensus=True
juju config tempo enable_tempo_http=True
juju config tempo enable_tempo_grpc=True
juju config tempo enable_otlp_grpc=True
juju config tempo enable_otlp_http=True
```
## Benefits
- Safeguarding against typos, unsupported protocols, duplications, ...etc. (e.g: otlp_https)
- We don't have to worry about storing the extra receivers somewhere.
- Simplicity in UX.
- Set of protocols is limited, and hopefully they will be reduced even more in the future.
## Disadvantages
- Maintenance overhead, as config options are dependable on the current supported protocols.

## Alternatives considered

### Comma separated config
Have a single config option to provide a comma-separated list of roles.

```
juju config tempo receivers=oltp_grpc,otlp_http
```
## Benefits
- We don't have to worry about storing the extra receivers somewhere.
## Disadvantages
- Prone to typos, unsupported protocols, duplications, ...etc. (e.g: otlp_https)
- Poor UX.

### Actions
Set extra receivers using an action to enable a specific extra receiver.
```
juju run tempo/0 enable-receiver otlp_grpc
```
## Benefits
- Safeguarding against typos, unsupported protocols, duplications, ...etc. (e.g: otlp_https)
## Disadvantages
- We have to store the extra receivers somewhere (e.g: peer relation data).
- Actions run on units, not apps, and are typically run on the leader unit.