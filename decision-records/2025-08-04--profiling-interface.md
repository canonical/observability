**Date:** 2025-05-28<br/>
**Author:** Pietro Pasotti(@PietroPasotti)  

## Context and Problem Statement

The profiling protocol and integrations are still in flux, as a consequence many products don't interoperate as well as they could;
e.g. parca can't talk to pyroscope/otelcol, and otelcol can't ingest certain formats that pyroscope supports.
We have been designing a `profiling` juju interface meant to be used to integrate pyroscope to otelcol, and any profiling source to otelcol.

However, the ingestion protocols supported by pyroscope and by otelcol are different.
So the question is: do we write a common `profiling` interface that exposes both protocols, or do we offer more 
specialized protocol-specific interfaces (e.g. `pyroscope_profiling`, `otlp_profiling`) that only exchange endpoint information 
for the protocols they represent?

## Decision 

We keep a common `profiling` interface, which will include all non-universally-shared protocols as optional fields, 
so that it can be used by all providers.

Example: 
- pyroscope supports ingesting over:
  - otlp-grpc
  - pyroscope-http (a collection of text formats in fact: https://grafana.com/docs/pyroscope/latest/reference-server-api/#ingestion)
- otelcol supports ingesting over:
  - otlp-grpc
  - otlp-http

So the databag model is going to be:
  - `otlp_grpc_endpoint_url:str`
  - `otlp_http_endpoint_url:Optional[str]`

We omit `pyroscope_http` for now, as we don't know of any requirer who might be interested in using it.
We can add it later as needed, again as an optional field since otelcol won't be able to provide it, but only pyroscope will.

## Benefits

A rather simple interface.

## Disadvantages

UX isn't as nice as dedicated interfaces, as it isn't immediately obvious if the provider supports 
the protocols a requirer is interested in. The requirer will have to manually check for the presence 
of the protocol it wants, and set blocked if not available.

## Alternatives considered

### Use dedicated per-protocol interfaces

### Disadvantages

- Deviates too much from the `tracing` design, which seems to work well for now
- More than one interface to do the same thing isn't nice
- Adds complexity to the charm API
