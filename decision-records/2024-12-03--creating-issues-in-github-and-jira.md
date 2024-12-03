# Creating issues in GitHub and Jira

**Date:** 2024-12-03<br/>
**Authors:** @simskij

## Context and Problem Statement

As the team have grown, we've ended up diverging in our practices on how to create issues in our
repositories. To be able to work efficiently and consistently with our issues, we need to follow some
common practices, so that the workflow remains the same across issues.

## Decision

These rules only apply to tickets opened by us. If someone else opens the ticket, we should
rephrase it as part of the triage.

### Issue Titles

- Issues are always to be created in GitHub, unless confidentiality requirements dictate something
  else. However, this is almost never the case. If you are unsure - ask @simskij or @sed-i.
- Issues of the story/enhancement type should have a title that describes the work to be done in
  the _imperative modus_, i.e "Add a bip to the bop", rather than "We should add a bip to the bop"
- Issues of the bug type should have a title that describes the bug occuring, written in
  this format: "When <condition> then <outcome>".
- Issue titles should _not_ contain any prefixes or namespaces, instead this should be part of
  the problem statement. I.e. "Write a document explaining the topic" rather than "[doc/explanation]
  Topic".

### Issue Estimation

- Issues should be estimated using the "Original time estimate"-field in Jira.
- Issues expected to take less than a full day of work (8 hours) should be estimated in full hours.
- Issues expected to take longer than a full day of work (8 hours) should be estimated in whole days.

### Pull Requests

- Pull request titles should be following the conventional commit format, which you can read
  [here](https://www.conventionalcommits.org/en/v1.0.0/). In essence,

  > <type>[(<scope>)]: description

  for example:

  > fix(charm-tracing): call the `setup` function whenever something is being set up
  
  The valid types are:
    - feature
    - chore
    - fix

## Considered alternatives

- https://gitmoji.dev/ for pull requests. Becomes annoying to parse, and hard to remember.
