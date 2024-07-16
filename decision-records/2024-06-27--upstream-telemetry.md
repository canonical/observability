# Upstream telemetry 
**Date:** 2024-06-27<br/>
**Authors:** @simskij

## Context and Problem Statement
The upstreams we have charmed to make up the observability stack in general have telemetry
gathering built-in. This is in general not something we consider a problem, but in airgapped environments
it floods logs with failed HTTP request attempts.

## Decision

We will have telemetry gathering on by default, but we will allow users to disable it using a juju
config option. We think of this as one of our ways to give back to the upstream.
