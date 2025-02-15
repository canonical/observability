# Up Alert Rules
**Date:** 2024-11-12
**Authors:** @dstathis

## Context and Problem Statement

Charms in the COS ecosystem currently have a wide range of different alert rules pertaining to the "up" metric. This
particular metric exists for all scrape targets and always behaves the same. Therefore we should have a uniform set of
alert rules.

## Accepted Solution

The folowing alert rule group should be used in each charm via proposals `(1)` and `(2)`:

```
groups:
- name: HostHealth
  rules:
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

This alert group provides 2 alerts.

HostDown: This unit has been unreachable for five minutes. At this point it is safe to assume it is down and an alert should be sent.

HostMetricsMissing: There is no up metrics for this host whatsoever. This can happen when the metrics for the host are pushed using remote write and therefore prometheus does not automatically generate an up metric.

## Note

We are currently using `$labels.instance` in the summary and description fields. We should instead be using `$labels.juju_unit`, but, many of our charms currently do not attach a `juju_unit` to their metrics. Once this has been fixed, we should switch to `$labels.juju_unit`.

## Proposals
### (1) Centralized alert rules
Charm authors should not have to implement their own HostHealth rules per charm and instead should be centrally managed in Prometheus (also Mimir) and aggregators like Grafana Agent. This reduces implementation error and avoids deviating from O11y team's best practice for up/absent alert rules.

### (2) Using a central alert rule store
With a standard for up/absent rules in place, it would be great if these alert rules exist in a central observability lib like `cosl`. This allows us to push updates to all charms/libs which intend to use these up/absent alert rules

### (3) Using absent_over_time instead of absent
We use absent(up) with for: 5m because the alert transitions from Pending to Firing. If query portability is desired, absent_over_time(up[5m]) is an alternative, but this will trigger without a Pending state after 5 minutes.

## History

2024-11-12 Initial adr by @dstatis
2025-02-14 Initial adr by @michaelthamm