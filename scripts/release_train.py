#!/usr/bin/env python3

"""
### Release train script

```
python3 release_train.py "grafana-k8s" "alertmanager-k8s" "tempo-k8s" "avalanche-k8s" "cos-configuration-k8s" "loki-k8s" "prometheus-pushgateway-k8s" "prometheus-scrape-target-k8s" "traefik-k8s" "traefik-route-k8s" "mimir-coordinator-k8s" "prometheus-scrape-config-k8s" "prometheus-k8s" "mimir-worker-k8s" "blackbox-exporter-k8s" "catalogue-k8s" "cos-proxy" "tls-truststore-operator"

"grafana-agent" "grafana-agent-k8s"
"karma-alertmanager-proxy-k8s" "karma-k8s"
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
    release_train(charms,
                  ask_for_confirmation=not skip_confirmation,
                  allow_stable_releases=allow_stable_releases)


if __name__ == '__main__':
    typer.run(main)
    # release_train(['karma-k8s'])
