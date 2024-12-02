# Dashboard title collision in Grafana
**Date:** 2024-11-07<br/>
**Authors:** @lucabello @sed-i


## Context and Problem Statement
Dashboard json includes keys such as in the following example:
```bash
$ cat metrics-dashboard.json | jq '{"title", "uid", "version", "tags"}'
{
  "title": "Loki Operator Overview",
  "uid": "loki",
  "version": 1,
  "tags": [
    "loki"
  ]
}
```

Grafana [documented](https://grafana.com/docs/grafana/latest/administration/provisioning/#reusable-dashboard-urls) that dashboards should not have the same *title* within a folder, or the same *uid* within
installations, which causes some problems in different scenarios.

This ADR addresses **title** collisions.

Dashboards from different charms may happen to have the same title:

`loki(dashboard "Overview") <--> grafana <--> tempo(dashboard "Overview")`

If both charms have a dashboard simply named "Overview", we'll have problems.
We should not put charm authors in a position where they need to be mindful of an entire hypothetical deployment and try
to avoid potential title collisions.


## Requirements
1. Dashboards must not have the same *title* within a folder.
2. Juju admins, not charm authors, should have the final say on how dashboards are organized in sub-folders.

## Decision
Let charm authors or admins specify the folder name under which grafana should place its dashboards.
We prefer to implement this on the provider side (grafana is requirer), so it's up to the charm author to expose this
functionality as a config option. If they choose to expose it, then the juju admin would indeed have the final say.

## Considered options
Deduplication can be addressed on the provider (charm with dashboards) or the requrier side (grafana charm).
In the following subsections, `P` and `R` stand for provider and requirer.

### (1/R) Place dashboards in folders by charm name

We can create a folder per charm (using the charm name, not the app name) and put the dashboard in there.
This is possible because the charm name is already part of the relation data schema (Appendix 1).

Under the top level folders named after the charm we'd preserve the tree structure the charm author had in place for the
dashboards.

### (2/P) Let charm authors or admins specify the folder name under which grafana should place its dashboards

This alternative relies on charm authors configuring their charms accordingly. The default behavior would be either the
"General" folder (as it is right now) or a folder named after the charm name.
We could add a constructor arg for the name of the folder. Charm authors can choose whether to expose it as a config
option. The constructor arg(s) could offer the following functionality:
- Default value is charm name
- Charm author could `preserve=True`, so that the tree structure of dashboards in the charm is preserved on grafana side
  as well. In any case, it will be nested under the toplevel value (which could be just `"."`, or `""`).

When this config option is changed, the Grafana charm would need to rearrange the dashboards tree accordingly.

Benefits:
- Allows solutions to have a unified folder (e.g., a `COS` folder for all of our charms).
- Charm authors can organize dashboards in whatever tree structure they like, and charm lib will flatten or preserve it.

Disadvantages:
- This availability of this functionality to juju admins would depend on the charm author's willingness to expose this
  as a config option.

## Appendix 1: grafana-dashboard relation schema
```bash
juju show-unit graf/0 --format=json \
  | jq -r '."graf/0"."relation-info" | .[] | select(.endpoint == "grafana-dashboard") | ."application-data".dashboards' \
  | jq '.templates'
```
```json
{
  "file:alertmanager_rev4.json": {
    "charm": "alertmanager-k8s",
    "content": "/Td6WFoAAA... (lzma base64) ...",
    "juju_topology": {
      "model": "welcome-k8s",
      "model_uuid": "5133e50a-f951-4715-81e2-d43b6d0a5fdd",
      "application": "am",
      "unit": "am/0"
    },
    "inject_dropdowns": true,
    "dashboard_alt_uid": "6140218c943801e8"
  }
}
```
