**Authors:** @ppasotti @mmkay

## Context

`charm_tracing` does two things:
- set up a tracing context (tracer, root span, root trace id...)
- autoinstrument charm code by auto-creating spans on all public method calls for the charm type and more
`ops[tracing]` now implements the first part, but not the second.

  
## Decision

We want to deprecate charm_tracing and nudge people into switching to `ops[tracing]`.

- Update `charm_tracing` to detect if ops-tracing is installed, and if so raise an exception and fail loudly with fix instructions.
- Release somewhere (cosl, `charm_tracing` charm lib) an `autoinstrument_charm` that does part 2 of what `charm_tracing` did.
- publish a new revision of `charm_tracing` that: 
  - pops a warning telling people to upgrade to ops-tracing and start using `autoinstrument_charm`
  - warn them that starting 25.10, `charm_tracing` will be sunsetted and no longer maintained.
  - it is not possible to use `charm_tracing` AND `ops[tracing]`
  
  

