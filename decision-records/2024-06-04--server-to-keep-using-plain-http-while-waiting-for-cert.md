**Date:** 2024-06-04<br/>
**Author:** @sed-i

## Context and Problem Statement
When an admin forms a tls relation, there is a time window in which:

1. the juju model tells us we must operate with TLS enabled; however
2. we haven't received the server cert yet.

As a result we had some code ordering issues (e.g. #414):
- Should we update the config file with the tls config, which includes path to
  the cert, before we got the cert, only to perfectly reflect the juju model?
- Should we wait with the tls config and allow the workload to continue to
  operate in plain http, in contradiction to the juju model?
- How should we determine within the charm if "TLS is enabled"?

This problem is common to all COS charms.

## Decision
A server shall keep using plain http while waiting for cert. The charm shall
have a "Waiting" status during that period (subject to other status
priorities).

We also distinguish between two substates:
- TLS enabled: we have a cert in relation data
- TLS active: the cert that is in relation data was written to disk and app
  config has a corresponding tls section.

```mermaid
stateDiagram-v2
    PlainHTTP: Workload operates in plain HTTP
    state PlainHTTP {
        [*] --> NoTLS : install
        NoTLS: No TLS relation, no certs on disk

        Waiting: CSR sent, waiting for cert
        NoTLS --> Waiting : tls-relation-joined
    }

    TLSEnabled: Cert written, app restarted, TLS enabled
    Waiting --> TLSEnabled : tls-relation-changed

    TLSEnabled --> TLSEnabled : cert update

    TLSEnabled --> NoTLS : cert revoked (e.g. relation-removed)
```

## Benefits
- We won't incur data loss on the server side.
- The receiver (server; e.g. Loki), should accept unecrypted data; it should be
  up to the sender (client; e.g. grafana-agent) to decide whether to send over
  plain http.

## Disadvantages
- If the client is happy with both and cert takes a long time to
  arrive (or never arrives), then we have a model departure: admin wanted TLS,
  but we keep operating in plain HTTP.

## Alternatives considered
- Stop operating in plain http mode as soon as a tls-certificates relation is
  formed.
