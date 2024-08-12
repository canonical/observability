**Date:** 2024-07-05<br/>
**Edited:** 2024-07-22<br/>
**Author:** Pietro Pasotti (@ppasotti), Michael Dmitry (@michaeldmitry)


## Context and Problem Statement
Tempo-k8s ought to support all receivers that upstream Tempo supports. After testing with different protocols from [opentelemetry receivers](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/) and referring to [Grafana Tempo source code](https://github.com/grafana/tempo/blob/main/modules/distributor/receiver/shim.go#L163C2-L169C3), the list of receivers supported by upstream Tempo comes down to 9 protocols: `zipkin`, `otlp_grpc`, `otlp_http`, `jaeger_grpc`, `jaeger_thrift_http`, `kafka`, `jaeger_thrift_compact`, `jaeger_thrift_binary`, `opencensus`.

### Problem 1
`kafka` protocol requires a running Kafka broker to run. If this protocol gets enabled in Tempo under `receivers` and we don't provide the address of a running broker, the Tempo workload will fail to start. The underlying reason for that is that the `kafka` receiver is using [Sarama](https://github.com/IBM/sarama) library that once gets instantiated, tries to dial the kafka broker addresses given as `brokers` under the [receiver options](https://github.com/MovieStoreGuy/opentelemetry-collector-contrib/tree/main/receiver/kafkareceiver). 

### Problem 2
`jaeger_thrift_compact` and `jaeger_thrift_binary` operate over `UDP` unlike all other protocols that run over `TCP`. The main issue is with `secured ingress` (like TLS in Traefik for TCP). 
- Upstream Traefik does not yet support [DTLS (The TLS for UDP)](https://github.com/traefik/traefik/issues/6642)
- `http3` in upstream Traefik works as a TCP entrypoint that takes TCP services and routers although it's a protocol running over UDP? [Traefik issue](https://github.com/traefik/traefik/issues/9050) states that it would handle the request under the scenes as TCP. With experimentation, proxying http3 requests through Traefik to Tempo on a UDP port did not work.

### Problem 3
Enabling `opencensus` over TLS is not working. Although TLS config is specified for `opencensus`, the running receiver server doesn't even seem to run with TLS (verified with multiple grpc and http clients). There are no issues on [Tempo](https://github.com/grafana/tempo/issues) that mentions Opencensus. However, [TLS configuration docs](https://grafana.com/docs/tempo/latest/configuration/network/tls/#receiver-tls) leave out `opencensus` from the list of protocols that can have the TLS config. 

## Decision 

- Tempo-k8s would support 5 receivers: `zipkin`, `otlp_grpc`, `otlp_http`, `jaeger_grpc`, `jaeger_thrift_http`.
  - Drop `kafka` receiver support from Tempo-k8s and document that. 
    - We could support `kafka`, but it would require adding an integration with a Kafka charm. Thus, we are choosing to not support it as a receiver until we get an ask for it.
  - Drop `jaeger_thrift_compact` and `jaeger_thrift_binary` receivers support from Tempo-k8s and document that.
  - Drop `opencensus` receivers support from Tempo-k8s and document that.
- Grafana-agent should support all receivers that Tempo-k8s supports
- For accepting traces from uncharmed applications:
  - Tempo-k8s has one "force-enable this config option" per protocol
  - Grafana-agent(vm AND -k8s) has one "force-enable this config option" per protocol
- Grafana-agent proxies traces to Tempo exclusively via otlp_grpc (we cannot change this), and sends charm traces via otlp_http
- Grafana-agent can be instructed to enable a specific (set of) protocol through cos-agent relation (instead of a separate tracing relation)
- Grafana-agent will communicate to all principal charms it is related to the full list of currently enabled receiver protocols (not just those that a specific principal requested to be opened)

## Benefits

- Uniform tracing protocol/receiver story across substrates
- Can enable tracing the same way you enable logging and metrics in machine charms
- Uniform integration path for uncharmed applications
- 'request one, get all' behaviour uniform with Tempo
- Promote sending secured traffic in the sense of not having partial support for protocols where unsecured traces are sent.

## Disadvantages

- Not supporting all protocols that upstream Tempo allegedly supports.

## Alternatives considered

- Have different subsets of supported protocols in tempo and grafana-agent
- Do not support uncharmed workloads on machine models, instead force them to CMR with tempo directly
- Have a partial support for UDP and TCP protocols without encryption (e.g: DTLS). 
