**Date:** 2025-08-07<br/>
**Author:** Pietro Pasotti(@ppasotti) & Michael Dmitry(@MichaelDmitry)

## Context and Problem Statement

The otel ebpf profiler snap is a system-wide profiling tool. 
So not only it doesn't make sense to have it running twice on the same host, it's also not possible since the snap can 
only be installed once and having two charms fighting over its configuration is not desirable.
If the charm that manages the snap is a subordinate, we risk conflicts if one wants to profile multiple co-located principals.

## Decision: principal charm 

The profiler should be a principal charm.
As a requisite to operation, it will attempt to acquire a machine-level lock and bug out on failure.

## Benefits

- Cleaner intent model: one profiler charm per machine.
- Clear error reporting if you attempt to deploy multiple profilers on the same machine.

## Disadvantages

- If you scale a workload charm (postgres), and you put it in a different VM, in order to profile the replica 
  you now must replicate the profiler as well and put it in the same machine. (some cognitive load)

## Alternatives considered

### Have it be a subordinate charm
#### Disadvantages

- weird because usually principal charms represent workloads (exception: k8s worker nodes, the ubuntu charm), and 
  if you want to profile two workloads that happen to run on the same machine, you'd have two system-wide profiler 
  charms running on the same machine.  
- Risk of confusion if you scale up multiple principals that have a profiler attached, and they end up being co-located.
- Less obvious semantically that the profiler is system-wide: scoping it to a principal makes you think it's workload-specific.



