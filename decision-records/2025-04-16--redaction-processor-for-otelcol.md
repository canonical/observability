**Date:** 2025-04-16

**Author:** Jose Massón (@Abuelodelanda)


<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Context and Problem Statement](#context-and-problem-statement)
- [Alternatives](#alternatives)
  - [`filelog` receiver](#filelog-receiver)
    - [Advantages](#advantages)
    - [Disadvantages](#disadvantages)
  - [`transform` processor](#transform-processor)
    - [Advantages](#advantages-1)
    - [Disadvantages](#disadvantages-1)
  - [`redaction` processor](#redaction-processor)
    - [Advantages](#advantages-2)
    - [Disadvantages](#disadvantages-2)
- [Decision: Transform Processor](#decision-transform-processor)
  - [Why not the others?](#why-not-the-others)
  - [Use these configs in a `pipeline`](#use-these-configs-in-a-pipeline)
- [Interaction through `juju` command line interface](#interaction-through-juju-command-line-interface)

<!-- markdown-toc end -->



## Context and Problem Statement

For applications that deal with sensitive, private data, the ability to mask certain fields or regular expressions in their logs is important, in some cases required. As OpenTelemetry Collector charm deployments will serve as the entry points for log data, they should support log masking before they send logs to Loki (or another destination).

This log masking feature should allow for specifying which field values to mask in the case of structured logs and regular expressions to use for masking parts of unstructurted log lines. These should be configurable through Juju config.


## Alternatives

### `filelog` receiver

[This receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/filelogreceiver/README.md) is part of the `contrib` distribution and **it is not** part of the [`opentelemetry-collector-rock`](https://github.com/canonical/opentelemetry-collector-rock).

It is only valid for log files read from disk.

Given this log line:

```
2025-04-14T10:45:32Z INFO User john.doe@example.com logged in with token abcdef123456
```

we want to mask email and token, like this:

```
2025-04-14T10:45:32Z INFO User *** logged in with token ***
```

The config for the `filelog` receive would be:

```yaml
receivers:
  filelog:
    include: [/var/log/myapp.log]
    start_at: beginning
    operators:
      - type: regex_parser
        regex: '(?P<log>.*)'
        parse_to: body

      - type: regex_replace
        regex: '(?P<log>.*)([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})(.*)'
        replace_with: "***"
        field: body

      - type: regex_replace
        regex: '(?P<before>.*token\s+)(?P<token>\w+)(?P<after>.*)'
        replace_with: "***"
        field: body
```

#### Advantages

- Processes logs at the entry point (early filtering)
- Supports regex match and replace via operators
- Can apply logic before data reaches processors


#### Disadvantages

- Only supports log from files, and we can receive logs in Loki format.
- It is not included in the `opentelemetry-collector-rock`.
- It is only a `receiver` not a processor we can inject into pipelines.
- Less flexible for structured JSON logs.
- The configuration is slightly more complex.



### `transform` processor

[This processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor) is part of the `contrib` distribution and **it is not** part of the [`opentelemetry-collector-rock`](https://github.com/canonical/opentelemetry-collector-rock).

The `transform` processor let us mask, remove and transform logs. It use `OTTL` syntax which is powerful but can be more complex.

```
2025-04-14T10:45:32Z INFO User john.doe@example.com logged in with token abcdef123456
```

we want to mask email and token, like this:

```
2025-04-14T10:45:32Z INFO User *** logged in with token ***
```

Here’s how to configure OpenTelemetry Collector to apply redactions using the transform processor:


```yaml
processors:
  transform/redact_email_token:
    log_statements:
      - context: log
        statements:
          # Redact email addresses in the body
          - replace_pattern(body, "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", "***")

          # Redact token values after the word "token"
          - replace_pattern(body, "(?<=token\\s)(\\w+)", "***")
```

In order to use this config for the `transfor` procesor in a pipeline, we need to add it like this:

```yaml
service:
  pipelines:
    logs/0:
      receivers:
      - loki
      processors:
      - transform/redact_email_token
      exporters:
      - loki/0
```

#### Advantages

- Uses [`OTTL`](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/ottl/README.md), a small, domain-specific programming language intended to process data with OpenTelemetry-native concepts and constructs.
- Highly flexible: supports conditional logic.
- Works well with structured data (JSON logs).
- Can remove, mask, or rename fields.



#### Disadvantages

- It is not included in the `opentelemetry-collector-rock`.
- `OTTL` syntax can be complex for new users.
- Less efficient than regex for simple match-and-replace

### `redaction` processor


[This processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/redactionprocessor) is part of the `contrib` distribution and **it is** part of the [`opentelemetry-collector-rock`](https://github.com/canonical/opentelemetry-collector-rock).

The `redaction` processor deletes span, log, and metric datapoint attributes that don't match a list of allowed attributes. It also masks attribute values that match a blocked value list. Attributes that aren't on the allowed list are removed before any value checks are done.

Given this log line:

```
2025-04-14T10:45:32Z INFO User john.doe@example.com logged in with token abcdef123456
```

we want to mask email and token, like this:

```
2025-04-14T10:45:32Z INFO User *** logged in with token ***
```


```yaml
processors:
  redaction/redact_email_token:
    blocked_values:
      - "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" ## email
      - "(?<=token\s)\w+"                                ## token
```

In order to use this config for the `redaction` procesor in a pipeline, we need to add it like this:

```yaml
service:
  pipelines:
    logs/0:
      receivers:
      - loki
      processors:
      - redaction/redact_email_token
      exporters:
      - loki/0
```


#### Advantages

- It is already enabled in the [`opentelemetry-collector-rock`](https://github.com/canonical/opentelemetry-collector-rock/blob/main/0.123.1/manifest.yaml#L25)
- It is specifically designed to prevent sensitive fields leaks.
- It is simple and direct for basic redaction use cases.
- Works on both structured and plain text logs


#### Disadvantages

- Less flexible for complex logic.
- blocked_values only replaces with asterisks (*)
- Cannot do advanced transformations or conditional logic


## Decision: Transform Processor

After evaluating the advantages and disadvantages of the three alternatives analysed, we chose to use the [`transform processor`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor).

It allows modifying, deleting, renaming, redirecting fields; works with conditions, complex expressions and nested structures. Although the learning curve of the OTTL language is a bit higher, it is consistent and powerful. It works equally well for structured logs (JSON), metrics, traces.

### Why not the others?


- `filelog` receiver: It is great for intercepting and modifying logs on the fly, but limited to file sources. If your logs come from somewhere else (OTLP, syslog, etc.), it's useless.

- `redaction` processor: It is very useful and easy, but only for masking and only with replacement by asterisks (`****`). You can't condition, change field names, or apply logic.


### Use these configs in a `pipeline`

In order to use one of these configs for the `transform` procesor in a pipeline, we need to add it like this:

```yaml
service:
  pipelines:
    logs/0:
      receivers:
      - loki
      processors:
      - redaction/redact_email_token
      exporters:
      - loki/0
```


## Interaction through `juju` command line interface

All the `transform` processor configs should be defined in a `yaml` file and their mapping to pipelines like this:

```shell
juju config otelcol transform_config='@path/to/transform_processor_config_file.yaml' transform_mapping='transform/redact_email_token:logs/0,logs/1`
```

The content of the `transform_config` config option is a `yaml` string or a file with a content like this one:

```yaml
processors:
  transform/redact_email_token:
    log_statements:
      - context: log
        statements:
          # Redact email addresses in the body
          - replace_pattern(body, "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", "***")

          # Redact token values after the word "token"
          - replace_pattern(body, "(?<=token\\s)(\\w+)", "***")
```
