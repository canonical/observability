**Date:** 2024-07-22<br/>
**Author:** Michael Dmitry (@michaeldmitry)  

## Context and Problem Statement
This is a follow-up on the ADR on [2024-07-05--tempo-receivers](2024-07-05--tempo-receivers.md#Decision) to decide which receivers would Tempo-k8s support. Tempo-k8s ought to support all receivers that upstream Tempo supports. After testing with different protocols from [opentelemetry receivers](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/) and referring to [Grafana Tempo source code](https://github.com/grafana/tempo/blob/main/modules/distributor/receiver/shim.go#L163C2-L169C3), the list of receivers supported by upstream Tempo comes down to 9 protocols: `zipkin`, `otlp_grpc`, `otlp_http`, `jaeger_grpc`, `opencensus`, `jaeger_thrift_http`, `kafka`, `jaeger_thrift_compact`, `jaeger_thrift_binary`.

### Problem 1
`kafka` protocol requires a running Kafka broker to run. If this protocol gets enabled in Tempo under `receivers` and we don't provide the address of a running broker, the Tempo workload will fail to start. The underlying reason for that is that the `kafka` receiver is using [Sarama](https://github.com/IBM/sarama) library that once gets instantiated, tries to dial the kafka broker addresses given as `brokers` under the [receiver options](https://github.com/MovieStoreGuy/opentelemetry-collector-contrib/tree/main/receiver/kafkareceiver). 

### Problem 2
`jaeger_thrift_compact` and `jaeger_thrift_binary` operate over `UDP` unlike all other protocols that run over `TCP`. The main issue is with `secured ingress` (like TLS in Traefik for TCP). 
- Upstream Traefik does not yet support [DTLS (The TLS for UDP)](https://github.com/traefik/traefik/issues/6642)
- `http3` in upstream Traefik works as a TCP entrypoint that takes TCP services and routers although it's a protocol running over UDP? [Traefik issue](https://github.com/traefik/traefik/issues/9050) states that it would handle the request under the scenes as TCP. With experimentation, proxying http3 requests through Traefik to Tempo on a UDP port did not work.

## Decision 

- Drop `kafka` receiver support from Tempo-k8s and document that. 
    - We could support `kafka`, but it would require adding an integration with a Kafka charm. Thus, we are choosing to not support it as a receiver until we get an ask for it.
- Drop `jaeger_thrift_compact` and `jaeger_thrift_binary` receivers support from Tempo-k8s and document that.

## Benefits

- Promote sending secured traffic in the sense of not having partial support for UDP protocols where unsecured traces are sent.

## Disadvantages

- Not supporting all protocols that upstream Tempo allegedly supports.

## Alternatives considered

### Unsecured UDP
Have a partial support for UDP protocols without encryption (e.g: DTLS). 

