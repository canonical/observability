# Observability

A repository to collect all of the initiatives around Observability currently being 
worked on at Canonical.

A list of all the active repositories maintained by the Observability team can be found using the [observability topic](https://github.com/search?q=topic%3Aobservability+org%3Acanonical+fork%3Atrue+archived%3Afalse&type=repositories).

Want to know more? See the [CharmHub topic page on Observability](https://charmhub.io/topics/canonical-observability-stack).

## Meta Repo

This repo also contains the manifest (`manifest.yaml`) for syncing all repositories maintained by the observability team.
The script assumes that you want to place all repos in the parent folder of the `observability` repo. To use it, do the following:

```
# install the git-metarepo module
$ pip3 install metarepo

# sync the repos using the manifest
$ git meta sync
```
