**Date:** 2024-06-03<br/>
**Author:** Pietro Pasotti (@ppasotti)  


## Decision 

- Tempo-k8s should support all receivers that upstream Tempo supports
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

## Disadvantages

- ??

## Alternatives considered

- Have different subsets of supported protocols in tempo and grafana-agent
- Do not support uncharmed workloads on machine models, instead force them to CMR with tempo directly
