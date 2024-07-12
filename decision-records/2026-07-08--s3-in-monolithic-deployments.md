# S3 in Monolithic Deployments
**Date:** 2024-07-08<br/>
**Authors:** @lucabello

## Context and Problem Statement
Currently, our Mimir HA solution doesn't require S3 when deployed in monolithic mode. However, this implies that, on a monolithic deployment (i.e., one coordinator and one worker), scaling up the worker will cause "data loss": the coordinator will start requiring S3 and thus the migration path will be worse.

This problem arose from the design of a shared coordinator object, in the context of checking whether there is an S3 relation (and eventually blocking if there isn't).

## Decision

We should require an S3 relation even in monolithic mode, so that it's possible to scale up seamlessly without losing data.
