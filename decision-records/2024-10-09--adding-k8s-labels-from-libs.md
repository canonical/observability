# Adding k8s Labels From Libraries
**Date:** 2024-07-16  
**Authors:** @dstathis @ca-scribner @IbraAoad

## Context and Problem Statement

To mark a pod as belonging to a given mesh, we need to apply a few labels.
For example, with istio we would need to e.g.:
```python
{
  "istio.io/dataplane-mode": "ambient",
  "istio.io/use-waypoint": waypoint_name,
  "istio.io/use-waypoint-namespace": waypoint_k8s_namespace,
}
```

In order for charms to join the mesh, the beacon charm sends this set of k8s labels over relation data that the charm must apply to
its pods. The `service_mesh` library should attempt to manage those labels.

Juju manages the labels of all deployments, so charm code must re-apply the labels after key lifecycle events:

1. Labels must match relation data after a leader change
2. Labels must match relation data after a pod restart
3. Labels must match relation data when relation data changes
4. Labels applied by anything outside the library should remain untouched

The issue seems to be when 1 and 3 happen at the same time (or 2 and 3). We will have no idea how the labels have
changed. For example, lets say relation data is `{"foo": "bar"}` and labels are set correctly. Then the relation data is
set reset to `{}` but the the leader pod dies at the same time. The new leader will come up and process the relation
changed event. It will see that it has no stored state and that matches relation data. So it will do nothing. The
`{"foo": "bar"}` label is now left on the pods unmanaged.

The issue stems from the fact that StoredState is scoped to the pod and not the charm. Even if `use_juju_for_storage` is
set to True, this issue will still persist. The usual solution would be to use a peer relation instead of StoredState
but since this is a library, we can't really impose this on the charm (or can we?)


## Accepted Solution

We should create a ConfigMap to be used as a way to store state. Thus we will have state which lives for the lifetime
of the charm and does not rely on controller storage (`use_juju_for_storage=True`). It also asks nothing extra from the charm developer.

The naming schema, to guarantee uniqeness, is: `juju-service-mesh-{self._charm.app.name}-labels`.


## Rejected Solutions

### Original (Bad) Solution:
* Only the leader processes labels
* Whenever the leader makes a change,  put the dict of labels it is responsible for in a StoredState.
* When a hook fires compare relation data to the stored state and apply the diff

### Distributed approach
We could use the original solution but have all units process events rather than just the leader. Assuming
`use_juju_for_storage` is set to True, this should mean that the StoredStates of each pod should be kept up to date and
it won't matter if the leader changes or restarts. The problem with this solution is we rely on the user to read the
docs and properly set `use_juju_for_storage` appropriately. Additionally, the future of `use_juju_for_storage` is
unclear. Also, this solution is a bit difficult to reason about due to complexity.

### Peer-relation approach
Simply use a peer relation and require the charm author to create this. It solves the issues stated in the proposed
solution but it is a bad developer experience.


## History

I (@dstathis) ran in to this problem when I was about to code up the original solution. After asking the team about it,
@ca-scribner came up with a solution using annotations. Later @IbraAoad modified the solution to use ConfigMaps instead.
