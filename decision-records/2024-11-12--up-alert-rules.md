# Up Alert Rules
**Date:** 2024-11-12
**Authors:** @dstathis

## Context and Problem Statement

Charms in the COS ecosystem currently have a wide range of different alert rules pertaining to the "up" metric. This
particular metric exists for all scrape targets and always behaves the same. Therefore we should have a uniform set of
alert rules.

## Accepted Solution

The folowing alert rule group should be used in each charm:

```
groups:
- name: HostHealth
  rules:
  - alert: HostUnreachable
    expr: up < 1
    for: 0m
    labels:
      severity: warning
    annotations:
      summary: Host '{{ $labels.instance }}' is unreachable.
      description: >-
        Host '{{ $labels.instance }}' is unreachable. This could indicate an availability issue and should be investigated.
  - alert: HostDown
    expr: up < 1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: Host '{{ $labels.instance }}' is down.
      description: >-
        Host '{{ $labels.instance }}' is down.
  - alert: HostMetricsMissing
    expr: absent(up)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: Metrics not received from host '{{ $labels.instance }}'.
      description: >-
        Metrics not received from host '{{ $labels.instance }}'. This is likely due to an issue with an itermediate metrics agent.
```

## Rationale

This alert group provides 3 alerts.

HostUnreachable: This is a useful informative rule but in many situations can be way to noisy, and so we put it at warning.

HostDown: This unit has been unreachable for five minutes. At this point it is safe to assume it is down and an alert should be sent.

HostMetricsMissing: There is no up metrics for this host whatsoever. This can happen when the metrics for the host are pushed using remote write and therefore prometheus does not automatically generate an up metric.

## Note

We are currently using `$labels.instance` in the summary and description fields. We should instead be using `$labels.juju_unit`, but, many of our charms currently do not attach a `juju_unit` to their metrics. Once this has been fixed, we should switch to `$labels.juju_unit`.

## History

2024-11-12 Initial adr by @dstatis
