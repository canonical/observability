**Date:** 2024-06-03<br/>
**Author:** Simon Aronsson (@simskij)  


## Decision 

Starting today, 2024-06-03, we will start documenting decisions that are too small for a proper spec, using ADRs. The
decision records will go into this repository, using an incrementally increasing-index-number, followed by a dash-separated
title, like `01-a-dash-separated-title.md`.

## Benefits

- We will know where to look for decisions
- We will capture the micro-decisions **somewhere** without the overhead of specs.

## Disadvantages

- Not localized to the charms
- Will have to be integrated into the PR workflow

## Alternatives considered

- Jira, which is disqualified on the basis of it not being available to the community.
- GitHub PRs, which is disqualified on the basis that it lacks discoverability
