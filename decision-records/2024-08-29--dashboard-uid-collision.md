# Dashboard uid collisions in Grafana
**Date:** 2024-08-29<br/>
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

This ADR addresses **uid** collisions.

#### Problem (a): Two charms on different revisions

`charm(rev1, dashboard v1) <--> grafana <--> charm(rev2, dashboard v2)`

Unless manually modified, `dashboard v1` and `dashboard v2` have the same *title* and *uid*, which will cause problems in Grafana.

#### Problem (b): New dashboard created by cloning an existing dashboard, neglecting to modify the UID

A common way to create a new dashboard is to clone and modify dashboard (local or from the grafana marketplace).
If the UID isn't modified (need to remeber to do it manually), then we'll end up with a UID collision (but the revision would be auto-incremented by the grafana UI, if saved and exported using grafana).

#### Problem (c): Unrelated dashboards that coincidentally happen to have the same UID

This is likely to happen when charm authors manually modify UIDs, assuming their (naive :) modification produced a unique ID (in the ecosystem!).


## Requirements
1. Dashboards must not have the same *uid* within installation.
2. Dashboard URL must be stable across dashboard updates (e.g. charm upgrades). Do not generate the UID from hashing
                                                                                                                                                                                                                                                                                                                                                                                                                             dashboard's entire contents, because it would break links to the dashboard.[^DbURL]
3. UID length must be <= 40 (grafana limit).
4. Should be able to easily tell from which charm each dashboard came.

## Decision
Implement all of:
- Automatically overwrite UIDs with a prescribed naming pattern at deploy/relate time, on the provider side
- On rev-collision, keep only the latest dashboard revision
- Add charm name to list of dashboard tags
- Update best practices doc to include workload tag

## Alternatives considered
Deduplication can be addressed on the provider (charm with dashboards) or the requrier side (grafana charm).
In the following subsections, `P` and `R` stand for provider and requirer.

### (1/P) Use a prescribed naming pattern for UIDs at dev time
We can update the [best practices doc](https://discourse.charmhub.io/t/grafana-k8s-docs-how-to-create-a-great-charmed-dashboard/14188#use-an-effective-naming-scheme-22),
and it's up to charm authors to be disciplined about adhering to it. Charm lib will raise if the pattern doesn't match the expected ("test-time linter").

A good option for UIDs could be `f"{charm_name}-{codename}"`, where `codename` is e.g. an abbreviate dashboard title that the charm author needs to make sure is unique within the charm.

Benefits:
- UID is human-readable and sensible.

Disadvantages:
- Coming up with a codename is toilsome.
- To adhere to this new standard, would need to modify all existing dashboards.

### (2/P) Automatically overwrite UIDs with a prescribed naming pattern at deploy/relate time, on the provider side
SHA1 is of length 40 (`len(hashlib.sha1(b"whatever").hexdigest()) == 40`), so calculate the dashboards UID from hashing (charm_name + relative_path of the dashboard file).

Benefits:
- The combination of charm_name and relative_path is almost guaranteed to be unique across the ecosystem. Exceptions:
  - Problem (a)
  - Local charm's name and dashboard relative_path collide with another charm.
- Change will be automatically rolled out to everyone by updating the dashboards charm lib.

Disadvantages:
- Keeping the dashboard itself intact but moving it to another subfolder would break dashboard URL.
- May need special attention for aggregation (grafana-agent, cos-proxy) and side-loading (cos-configuration).
- Overwriting without asking might be surprising for users who want to control UIDs themselves.
- Dashboards taken from the grafana marketplace would lose their original identity.

### (3/R) Automatically overwrite UIDs with a prescribed naming pattern on relation changed, on the requirer side
This is possible, thanks to the schema we already have in place (see Appendix 1).

Similar benefits and disadvantages to doing it on the provider side.

### (4/R) On rev-collision, keep only the latest dashboard revision

If we received a "newer dashboard" from a higher revision of a charm, we'd only keep the latest dashboard.

Benefits:
- A workaround for problem (a).

Disadvantages:
- When different charm revisions are related to grafana, will be able to see only the newest dashboard, which may be incompatible with the set of metrics exposed by the older revision.


### (5/P) Add charm name to list of dashboard tags

This would make it easy to tell from which charm each dashboard came. This is useful in finding the author of a buggy dashboard.
The tag could look like this: `charm-name:rev`, if the charm revision is available to charm code.


### (6) Update best practices doc to include workload tag

Dashboards should have a tag for the workload name (not application name) they are intended for.
For example: "Loki".


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

[^DbURL]: Dashboard URL is determined by its UID and the chain of parent folders under which it is stored on disk. 
