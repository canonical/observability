# Arbitrary config for OpenTelemetry Collector
**Date:** 2025-03-17

**Authors:** Jose Massón

## Context and Problem Statement

Unlike Grafana-agent, OpenTelemetry Collector allows us enable multiple receivers, processors, exporters and extensions. This of course provides a flexibility we did not have with grafana-agent, but that flexibility comes at an additional cost: The configuration file tend to be more complex.

Generating complex configurations is not trivial nor flexible in an event-driven system like Juju. So we need to come up with a solution that produces out-of-the-box a simple and functional configuration but with the possibility of enhance it with arbitrary configs.

The OpenTelemetry config file has 5 main sections:


| Section     | Description                                                                   |
| ----------- | ----------------------------------------------------------------------------- |
| `receivers` | To define where datasources are configured (logs, metrics, traces).           |
| `processors`| To modify, filter or transform the data before sending them.                  |
| `exporters` | To define where telemetry is going to be sent. (Loki, Prometheus, OTLP, etc.).|
| `service`   | To define the pipelines which connects receivers, processors and exporters.   |
| `extensions`| To configure extra features like health checks, authentication, encoding, etc.|


The `receivers` section could be auto-generated based on the established relations, for example if we implement `cos-agent` interface we could generate something like this:

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: "my-app"
          static_configs:
            - targets: ["localhost:9090"]

  # To read logs from disk
  filelog:
    include: ["/var/log/my-app.log"]
    start_at: beginning
    include_file_path: true
    include_file_name: false
    operators:
      - type: regex_parser
        regex: '^(?P<timestamp>\S+) (?P<log_level>\S+) (?P<message>.*)$'
        timestamp:
          parse_from: timestamp
          layout: "%Y-%m-%dT%H:%M:%S.%fZ"

  # To receive logs
  loki:
    protocols:
      http:
        endpoint: 0.0.0.0:3500
    use_incoming_timestamp: true

  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
```


The `exporters` sections could be ato-generated also based on the relations established, for example:

```yaml
exporters:
  prometheus:
    endpoint: "http://prometheus-server:9090/metrics"

  loki:
    endpoint: "http://loki-server:3100/loki/api/v1/push"

  tempo:
    endpoint: "http://tempo-server:3200/api/traces"
```


Finally the `service` section will relate `receivers` and `exporters`

```yaml
service:
  pipelines:
    metrics:
      receivers: [prometheus]
      exporters: [prometheus]

    logs:
      receivers: [loki, filelog]
      exporters: [loki]

    traces:
      receivers: [otlp]
      exporters: [tempo]
```


With configs like those ones we can replicate grafana-agent behaviour. Now we need to decide how to add `processors` and `extensions` to the config fiel.


## Alternative 1: `juju config`

In order to include `processors` or `extensions` we may use `juju config`, like this:

```shell
juju config otel-col processors_file='@path/to/processors-config.yaml' to_pripelines='metrics'
```

Let's imagin we want to enable the [`metricsgeneratorprocessor`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/metricsgenerationprocessor) to the `metrics` pipeline, we need to create a file with like this one:

```yaml
metricsgenerator:
    rules:
        # create pod.cpu.utilized following (pod.cpu.usage / node.cpu.limit)
        - name: pod.cpu.utilized
          type: calculate
          metric1: pod.cpu.usage
          metric2: node.cpu.limit
          operation: divide

        # create pod.memory.usage.bytes from pod.memory.usage.megabytes
        - name: pod.memory.usage.bytes
          unit: Bytes
          type: scale
          metric1: pod.memory.usage.megabytes
          operation: multiply
          scale_by: 1048576
```

Once this config is added, the config file will have a new section `processors` like this:

```yaml
processors:
  metricsgenerator:
      rules:
          # create pod.cpu.utilized following (pod.cpu.usage / node.cpu.limit)
          - name: pod.cpu.utilized
            type: calculate
            metric1: pod.cpu.usage
            metric2: node.cpu.limit
            operation: divide

          # create pod.memory.usage.bytes from pod.memory.usage.megabytes
          - name: pod.memory.usage.bytes
            unit: Bytes
            type: scale
            metric1: pod.memory.usage.megabytes
            operation: multiply
            scale_by: 1048576
```

and the `service` section will be like this:

```yaml
service:
  pipelines:
    metrics:
      receivers: [prometheus]
      processors: [metricsgenerator]
      exporters: [prometheus]

    logs:
      receivers: [loki, filelog]
      exporters: [loki]

    traces:
      receivers: [otlp]
      exporters: [tempo]
```


On the other hand of we need to add `extensions` we may execute:

```shell
juju config otel-col extensions_file='@path/to/extensions-config.yaml'
```

The `extensions-config.yaml` would contain something like this:

```yaml
health_check:
  endpoint: 0.0.0.0:13133
pprof:
  endpoint: 0.0.0.0:1777
```

And the config will have a new `extensions` section like this:

```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  pprof:
    endpoint: 0.0.0.0:1777
```

and the `service` section will have a new `extensions` section:

```yaml
service:
  extensions: [health_check, pprof]
  pipelines:
    metrics:
      receivers: [prometheus]
      processors: [metricsgenerator]
      exporters: [prometheus]

    logs:
      receivers: [loki, filelog]
      exporters: [loki]

    traces:
      receivers: [otlp]
      exporters: [tempo]
```

## Alternative 2: juju actions




## Alternative 3





## History

2025-03-17 Initial adr by Jose Massón
