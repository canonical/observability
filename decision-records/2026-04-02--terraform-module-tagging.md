**Date:** 2026-04-02<br/>
**Author:** Michael Thamm (@crucible)

## Context and Problem Statement

Prior discussion was conducted in this GitHub issue:
- https://github.com/canonical/observability/issues/427

with 2 Observability team Cafes to come to an agreement. This document will summarize the agreed direction for tagging Terraform charm and product modules.

## Decision: use separate full-SemVer tag dedicated to Terraform

Design goals:
- Clear Terraform mapping to solution track / charm workload version
- Strict pinning (precise reproducibility)
- Tagging must be compatible with Terrareg

In the context of __Terraform-first Juju operations__,
facing __the friction between track-first and SemVer-first tagging__,
we decided for __Separate full-SemVer tag dedicated to Terraform__,
and rejected __Major.minor, metadata__,
to achieve __strict reproducability__,
accepting __version opaqueness__.

## User experience
1. First deployment
    - *terraform apply*
2. In-track refresh
    - No change to source e.g., ?ref=1.0.0
    - Update the risk or revision input; TF validation guides the user
    - *terraform apply*
3. Cross-track refresh
    - Update the source e.g., ?ref=2.0.0
    - Update the channel or revision input; TF validation guides the user
    - Read the module’s docs for extra guidance
    - *terraform apply*
4. Revert failed deployment
    - Revert to the most recently used (working) version
    - *terraform apply*

## Implementation
1. OBC-1544 “26.04 LTS prep and dogfooding” will address:
    - Implementing the tagging rework of our TF modules (charms and products)
    - Implement tagging CI on version bump
2. OBC-1760 “Terraform-first end-to-end charm lifecycle” will address:
    - Ensuring users can upgrade/downgrade in-track/cross-track our products with tagging

## Appendix - extra context

We need to conform to the [CC008](https://docs.google.com/document/d/1k1psLCfcf0Nr5KeVtWGFi9wmzhcg5AP9GVZTsRyVQSQ/edit?tab=t.0) spec and our solution must:
- have friendly UX for our users
- be extendible to product modules
- be automatable: tagging the repo and releasing to the TF registry

### Maintenance scenarios
| Upstream | Track | Cycle | Event | Tag |
|---|---|---|---|---|
| `3.6.7` | `3.6` | `26.04` | | `1.0.0` |
| | | | A TF endpoint added to track `3.6` | `1.1.0` |
| | | | A TF endpoint added to previous track e.g., `2.9` | `n-1.n+1.0` or `n.n+1.0` |
| `3.6.7` | `3.6` | `26.10` | We consciously decide not to track bump (to `3.7.0`) across cycles | `1.1.0` |
| `4.1.0` | `4.1` | `27.04` | We time a breaking change with `27.04` | `2.0.0` |
| | | | We decide to make a breaking change mid-cycle | `3.0.0` |

### Shortcomings of our decision
- ❗️Tags are opaque to charm-tracks e.g., `1.0.0` is specific to track `2`.
	- A user needs to search release notes / module docs to understand what tracks are allowed.
- We have to manage a `VERSION` file for tagging CI.
