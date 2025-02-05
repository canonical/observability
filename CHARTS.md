Here's some charts to visualize and better explain what happens in our workflows.

## Charm Workflows

### Quality Checks

This workflows is used by other workflows to perform a series of quality checks on a charm.

```mermaid
flowchart TD
  qc[["Quality Checks"]]
  subgraph lint["**Linting**"]
    direction LR
    lintcode["Code"]
    lintalerts["Alert Rules"]
    lintterraform["Terraform"]
    lintcode ~~~ lintalerts
    lintalerts ~~~ lintterraform
  end
  subgraph staticqc["**Static Analysis**"]
    direction LR
    static["Static Checks"]
    unit["Unit Tests"]
    static ~~~ unit
  end
  subgraph otherqc["**Other Checks**"]
    direction LR
    codeql["CodeQL Analysis"]
    woke["Inclusive Naming"]
    codeql ~~~ woke
  end
  
  pack["Pack the Charm"]
  itestssequential["Integration Tests<br>(sequential)"]
  itestsparallel["Integration Tests<br>(parallel)"]


qc --> lint
lint --> staticqc
staticqc --> otherqc

otherqc --> pack
pack -->|parallelize-integration: false| itestssequential
pack -->|parallelize-integration: true| itestsparallel

style qc stroke-width:3px
style lint opacity:0.4
style staticqc opacity:0.4
style otherqc opacity:0.4
```

### Pull Request

```mermaid
flowchart TD
  commit[["Commit on a PR"]]
  ciignore{{"Decide if the CI should run"}}
  endignore(["Skip the CI"])
  libcheck["Add the <br>**[Libraries: Out of Date]**<br>label to the PR if necessary"]

  qualitychecks[["Quality Checks"]]

commit --> ciignore
ciignore -->|Only .md and workflow changes| endignore
ciignore -->|The PR changes affect the charm| libcheck

libcheck --> qualitychecks


style commit stroke-width:3px
style qualitychecks stroke-width:3px
```

### Release Charm

``` mermaid
flowchart TD
  merge[["Merge to *main* or _track/*_"]]
  ciignore{{"Decide if the CI should run"}}
  endignore(["Skip the CI"])

  qualitychecks[["Quality Checks"]]
  split{{"Spin up one runner per **arch** in *charmcraft.yaml* (*amd, arm*)"}}
  packamd["Pack the charm (*amd*)"]
  packarm["Pack the charm (*arm*)"]
  releaseamd["Release the charm<br>(all bases, *amd*)"]
  releasearm["Release the charm<br>(all bases, *arm*)"]
  gittagamd["Create revision tag on GitHub (*amd*)"]
  gittagarm["Create revision tag on GitHub (*arm*)"]


merge --> ciignore
ciignore -->|Only .md and workflow changes| endignore
ciignore -->|The PR changes affect the charm| qualitychecks
qualitychecks --> split
split -->|platforms: amd64| packamd
split -->|platforms: arm64| packarm
packamd --> releaseamd
packarm --> releasearm
releaseamd --> gittagamd
releasearm --> gittagarm


style merge stroke-width:3px
style qualitychecks stroke-width:3px
```

### Update Libraries

```mermaid
flowchart TD
  start[["⏱️ On a  schedule"]]
  automerge["Merge pre-existing *chore/auto-libs* PRs with green CI"]
  start --> automerge
  checkmajor["Check for **major** charm library updates"]
  automerge --> checkmajor
  openissue["Open a GitHub issue asking to update"]
  checkmajor -->|👍 There is at least a new major version| openissue
  fetchlib["Update minor versions with<br>*charmcraft fetch-lib*"]
  openissue --> fetchlib
  checkmajor -->|👎 No new major version| fetchlib
  createpr["Push to *chore/auto-libs* and create a PR"]
  fetchlib --> createpr

style start stroke-width:3px
```
