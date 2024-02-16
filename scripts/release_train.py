#!/usr/bin/env python3

"""
# Release train script

This module contains a CLI script for unleashing the charm release bump train.
For all input charms, the script will:
- grab whatever revision is on edge and release it to beta
- grab whatever revision is on beta and release it to candidate
- grab whatever revision is on candidate and release it to stable

(this includes any resources linked to that revision)

Special cases:
- if there is nothing released on stable, candidate will remain on candidate (unless the script is run with the --stable flag).
- if the revisions are the same, nothing will be bumped

For example, suppose the starting situation is:
```
$ charmcraft status foo
Track    Base                  Channel    Version    Revision    Resources
latest   ubuntu 20.04 (amd64)  stable     -          -           agent-image (r30)
                               candidate  45         45          agent-image (r30)
                               beta       47         47          agent-image (r30)
                               edge       47         47          agent-image (r31)
1.0      ubuntu 20.04 (amd64)  stable     50         50          agent-image (r30)
                               candidate  50         50          agent-image (r30)
                               beta       56         56          agent-image (r31)
                               edge       56         56          agent-image (r31)
```

Then run `release_train.py foo`; now you should see (note the changes ` <<!>>`):
```
$ charmcraft status foo
Track    Base                  Channel    Version    Revision    Resources
latest   ubuntu 20.04 (amd64)  stable     -          -           agent-image (r30)
                               candidate  47         47          agent-image (r30) <<!>>
                               beta       47         47          agent-image (r30)
                               edge       47         47          agent-image (r31)
1.0      ubuntu 20.04 (amd64)  stable     50         50          agent-image (r30)
                               candidate  56         56          agent-image (r31) <<!>>
                               beta       56         56          agent-image (r31)
                               edge       56         56          agent-image (r31)
```

Suppose you now release a new `edge` version on 1.0 and then run `release_train.py foo --stable`;
now you should see (note the changes ` <<!>>`):
```
$ charmcraft status foo
Track    Base                  Channel    Version    Revision    Resources
latest   ubuntu 20.04 (amd64)  stable     47         47          agent-image (r30) <<!>>
                               candidate  47         47          agent-image (r30)
                               beta       47         47          agent-image (r30)
                               edge       47         47          agent-image (r31)
1.0      ubuntu 20.04 (amd64)  stable     56         56          agent-image (r31) <<!>>
                               candidate  56         56          agent-image (r31)
                               beta       57         57          agent-image (r32) <<!>>
                               edge       57         57          agent-image (r32) <<!>>
```
"""

import json
import logging
import shlex
from collections import defaultdict
from subprocess import Popen, PIPE
from typing import Optional, List

import typer

logger = logging.getLogger(__name__)

bump_train = {
    'edge': 'beta',
    'beta': 'candidate',
    'candidate': 'stable',
    'stable': None
}


def _run_cmd(cmd: str):
    print(f"executing {cmd}")
    proc = Popen(shlex.split(cmd), stdout=PIPE, text=True)
    proc.wait()


def _get_json(cmd: str):
    cmd += ' --format=json'
    proc = Popen(shlex.split(cmd), stdout=PIPE, text=True)
    proc.wait()
    out = proc.stdout.read()
    return json.loads(out)


def get_release_info(charm: str):
    logger.debug(f"gathering charmcraft status for {charm}")
    cmd = f'charmcraft status {charm}'
    status = _get_json(cmd)
    out = {}
    for track in status:
        releases_per_base = {}
        track_name = track['track']
        out[track_name] = releases_per_base

        logger.debug(f"processing track {track_name}")

        for mapping in track['mappings']:
            base = mapping['base']
            base_name = f"{base['name']}-{base['channel']}-{base['architecture']}"
            releases_to_bump = {}
            releases_per_base[base_name] = releases_to_bump

            logger.debug(f"processing base {base}")
            releases = mapping['releases']
            for release in releases:
                for elem, next_ in bump_train.items():
                    if (channel := release['channel']) == f"{track_name}/{elem}":
                        release['bump_to_risk'] = next_
                        release['bump_to'] = f"{track_name}/{next_}"
                        releases_to_bump[channel] = release
    return out


def get_max_revs_per_channel(releases_to_bump):
    charm_revisions = defaultdict(list)
    resource_revisions = defaultdict(dict)

    for track_name, track in releases_to_bump.items():
        charm_revisions[track_name].append(track['revision'] or None)
        for resource in track['resources'] or ():
            if not resource_revisions[track_name].get(resource['name']):
                resource_revisions[track_name][resource['name']] = []
            resource_revisions[track_name][resource['name']].append(resource['revision'] or 0)

    max_charm_revs = {a: max(b) for a, b in charm_revisions.items()}
    max_resource_revs = {res_name: {a: max(b) for a, b in res_def.items()} for res_name, res_def in
                         resource_revisions.items()}
    return max_charm_revs, max_resource_revs


def get_bump_cmds(charm: str, info: dict, allow_stable_releases: bool):
    out = set()
    for track_name, releases_per_base in info.items():
        for base, releases_to_bump in releases_per_base.items():

            for channel, release in releases_to_bump.items():
                if not allow_stable_releases and release['bump_to_risk'] == 'stable' and \
                        releases_to_bump.get(release['bump_to'])['revision'] is None:
                    logger.warning(f"skipped releasing {charm} rev {release['revision']} on {release['channel']} "
                                   f"as there is nothing on stable yet. Pass --stable to allow.")

                if release['bump_to_risk'] is None:
                    logger.debug(f"skipping {channel} ({base}): already maxed out.")
                    continue

                next_revision = releases_to_bump.get(release['bump_to'], {}).get('revision')
                next_resources = releases_to_bump[release['bump_to']]['resources']

                if release['revision'] == next_revision and release['resources'] == next_resources:
                    # charm is already at the same revision as the next channel
                    # charm resources are already at the same revision as the next channel
                    logger.debug(f"skipping {channel} ({base}): already bumped.")
                    continue

                cmd = (f"charmcraft release {charm} "
                       f"--channel={release['bump_to']} "
                       f"--revision={release['revision']}")

                for resource in release['resources']:
                    cmd += f" --resource={resource['name']}:{resource['revision']}"
                out.add(cmd)

    return list(out)


def release_train(charms: List[str], ask_for_confirmation: bool = True, allow_stable_releases: bool = False):
    infos = []

    with typer.progressbar(charms) as charms:
        for charm in charms:
            infos.append((charm, get_release_info(charm)))

    print('all done. Calculating deltas... \n')

    cmds = []
    for charm, info in infos:
        bump_train_for_charm = get_bump_cmds(charm, info, allow_stable_releases)
        if bump_train_for_charm and ask_for_confirmation:
            for cmd in bump_train_for_charm:
                print(f"\t >>> {cmd}")

        print()
        cmds += bump_train_for_charm

    if not cmds:
        print('nothing to do.')
        return

    if ask_for_confirmation:
        if not typer.confirm("confirm?"):
            print('aborted.')
            return

    for cmd in cmds:
        _run_cmd(cmd)

    print(f'released {len(cmd)} versions.'
          f'Pat yourself on the back.')


def main(
        charms: Optional[List[str]] = typer.Argument(None),
        skip_confirmation: bool = typer.Option(False, "--yolo", is_flag=True),
        allow_stable_releases: bool = typer.Option(False, "--stable", is_flag=True),
):
    release_train(
        charms,
        ask_for_confirmation=not skip_confirmation,
        allow_stable_releases=allow_stable_releases
    )


if __name__ == '__main__':
    typer.run(main)
