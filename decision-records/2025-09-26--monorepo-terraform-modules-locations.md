**Date:** 2025-09-26<br/>
**Author:** Mateusz Kulewicz (@mmkay)

## Context and Problem Statement

The terraform modules for monorepos are not aligned on the location - some are in the `observability-stack` repository, others are in the monorepo repositories

## Decision: terraform modules for monorepos live in the same repo as the charms

The terraform modules for monorepos live in the same repository as the charms, in the `terraform` directory. This is a summary of an earlier decision that wasn't written down.

## Benefits

- The code that's related to the module lives next to the charms code
- Its location is standardized

## Disadvantages

- The bundles in observability-stack need to import the modules from another repository

## Alternatives considered

### Have all modules live in the shared observability-stack repository

The downside of that is that the modules for each individual charm anyway live next to the charm, so the boundary appears to be more artificial.