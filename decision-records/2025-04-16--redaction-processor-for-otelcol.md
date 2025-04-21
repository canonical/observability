**Date:** 2025-04-16
**Author:** Jose Massón (@Abuelodelanda)


<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Context and Problem Statement](#context-and-problem-statement)
- [Decision: Redaction Processor](#decision-redaction-processor)
  - [Config examples](#config-examples)
    - [Log record in plain text format](#log-record-in-plain-text-format)
    - [Log record in JSON format](#log-record-in-json-format)
    - [Use these configs in a `pipeline`](#use-these-configs-in-a-pipeline)
  - [How Loki stores the redacted logs:](#how-loki-stores-the-redacted-logs)
    - [Log record in plain text format:](#log-record-in-plain-text-format)
    - [Log record in JSON format:](#log-record-in-json-format)
- [Interaction through `juju` command line interface](#interaction-through-juju-command-line-interface)

<!-- markdown-toc end -->



## Context and Problem Statement

For applications that deal with sensitive, private data, the ability to mask certain fields or regular expressions in their logs is important, in some cases required. As OpenTelemetry Collector charm deployments will serve as the entry points for log data, they should support log masking before they send logs to Loki (or another destination).

This log masking feature should allow for specifying which field values to mask in the case of structured logs and regular expressions to use for masking parts of unstructurted log lines. These should be configurable through the charm libraries, relations and / or through Juju config.

OpenTelemetry Collector charms support masking logs before they are shipped to Loki (or another destination) with fields / regex specified through configuration.


## Decision: Redaction Processor

We will use the [redaction processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/processor/redactionprocessor) which will be enabled in the otelcol binaries we ship since it is specifically designed to prevent sensitive fields from leaking into your telemetry data. It offers powerful tools to:

 - Remove any attributes not included in a predefined list of permitted attributes.
 - Strip confidential information from telemetry to prevent accidental data exposure.
 - Mask or obfuscate sensitive attribute values that match standard patterns.



### Config examples

#### Log record in plain text format

In a log line like this one:

```
2025-04-14T10:45:32Z INFO User john.doe@example.com logged in with token abcdef123456
```

We need to::

 - Mask the email → `***`
 - Mask the token → `***`

The `redaction` processor config block looks like:

```yaml
processors:
  redaction/redact_email_token:
    rules:
      - name: redact_email
        pattern: '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
        replacement: '***'
      - name: redact_token
        pattern: 'token\s+\w+'
        replacement: 'token ***'
```


#### Log record in JSON format

```json
{"timestamp": "2025-04-14T10:45:32Z", "level": "INFO", "user": "john.doe@example.com", "token": "abcdef123456", "action": "login"}
```

We need to::

 - Mask the email → `***`
 - Mask the token → `***`


The `redaction` processor config block looks like:

```yaml
processors:
  redaction/redact_email_token:
    rules:
      - name: redact_email
        pattern: '"user":\s*"[^"]+@[^"]+"'
        replacement: '"user": "***"'
      - name: redact_token
        pattern: '"token":\s*"[^"]+"'
        replacement: '"token": "***"'
```


#### Use these configs in a `pipeline`

In order to use one of these configs for the `redaction` procesor in a pipeline, we need to add it like this:

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

### How Loki stores the redacted logs:

Loki stores the modified logs these ways

#### Log record in plain text format:
```json
{
  "stream": {
    "job": "my-job",
    "filename": "/var/log/myapp.log",
    "level": "INFO"
  },
  "values": [
    [
      "1713081932000000000",
      "2025-04-14T10:45:32Z INFO User *** logged in with token ***"
    ]
  ]
}
```

#### Log record in JSON format:

```json
{
  "stream": {
    "job": "my-job",
    "filename": "/var/log/myapp.log",
    "level": "INFO"
  },
  "values": [
    [
      "1713081932000000000",
      "{\"timestamp\": \"2025-04-14T10:45:32Z\", \"level\": \"INFO\", \"user\": \"***\", \"token\": \"***\", \"action\": \"login\"}"
    ]
  ]
}
```

## Interaction through `juju` command line interface

The `redaction` processor confis should be defined in a `yaml` file and their mapping to pipelines like this:

```shell
juju config otelcol redaction_file='@path/to/redaction_processor_config_file.yaml' pipelines_mapping='redaction/redact_email_token=logs/0, redaction/redact_email_token=logs/1`
```
