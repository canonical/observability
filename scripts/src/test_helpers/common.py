# Copyright 2024 Canonical Ltd.
# See LICENSE file for licensing details.

"""A set of common functions used for deploying minio and s3-integrator useful in integration tests."""

import logging
import subprocess
from dataclasses import dataclass
from typing import Dict, Optional

import yaml
from juju.application import Application
from juju.unit import Unit
from minio import Minio
from pytest_operator.plugin import OpsTest

from scripts.src.test_helpers.juju import Juju, WorkloadStatus

logger = logging.getLogger(__name__)

_JUJU_KEYS = ("egress-subnets", "ingress-address", "private-address")
_JUJU_DATA_CACHE = {}

ACCESS_KEY = "accesskey"
MINIO = "minio"
BUCKET_NAME = "tempo"
SECRET_KEY = "secretkey"
S3_INTEGRATOR = "s3-integrator"
S3_APP_NAME = "s3"


def get_unit_info(unit_name: str, model: str = None) -> dict:
    """Return unit-info data structure.

     for example:

    traefik-k8s/0:
      opened-ports: []
      charm: local:focal/traefik-k8s-1
      leader: true
      relation-info:
      - endpoint: ingress-per-unit
        related-endpoint: ingress
        application-data:
          _supported_versions: '- v1'
        related-units:
          prometheus-k8s/0:
            in-scope: true
            data:
              egress-subnets: 10.152.183.150/32
              ingress-address: 10.152.183.150
              private-address: 10.152.183.150
      provider-id: traefik-k8s-0
      address: 10.1.232.144
    """
    cmd = f"juju show-unit {unit_name}".split(" ")
    if model:
        cmd.insert(2, "-m")
        cmd.insert(3, model)

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    raw_data = proc.stdout.read().decode("utf-8").strip()

    data = yaml.safe_load(raw_data) if raw_data else None

    if not data:
        raise ValueError(
            f"no unit info could be grabbed for {unit_name}; "
            f"are you sure it's a valid unit name?"
            f"cmd={' '.join(proc.args)}"
        )

    if unit_name not in data:
        raise KeyError(unit_name, f"not in {data!r}")

    unit_data = data[unit_name]
    _JUJU_DATA_CACHE[unit_name] = unit_data
    return unit_data


def purge(data: dict) -> None:
    """Purge the dict from added address, ingress, egress information."""
    for key in _JUJU_KEYS:
        if key in data:
            del data[key]


def get_relation_by_endpoint(
        relations: dict, local_endpoint: str, remote_endpoint: str, remote_obj: dict
) -> dict:
    """Find a matching endpoint relation. Returns a single entry and throws an error if there are none / more than 1."""
    matches = [
        r
        for r in relations
        if (
                   (r["endpoint"] == local_endpoint and r["related-endpoint"] == remote_endpoint)
                   or (r["endpoint"] == remote_endpoint and r["related-endpoint"] == local_endpoint)
           )
           and remote_obj in r["related-units"]
    ]
    if not matches:
        raise ValueError(
            f"no matches found with endpoint=="
            f"{local_endpoint} "
            f"in {remote_obj} (matches={matches})"
        )
    if len(matches) > 1:
        raise ValueError(
            "multiple matches found with endpoint=="
            f"{local_endpoint} "
            f"in {remote_obj} (matches={matches})"
        )
    return matches[0]


@dataclass
class UnitRelationData:
    """A dataclass for unit relation."""

    unit_name: str
    endpoint: str
    leader: bool
    application_data: Dict[str, str]
    unit_data: Dict[str, str]


def get_content(
        obj: str, other_obj, include_default_juju_keys: bool = False, model: str = None
) -> UnitRelationData:
    """Get the content of the databag of `obj`, as seen from `other_obj`."""
    unit_name, endpoint = obj.split(":")
    other_unit_name, other_endpoint = other_obj.split(":")

    unit_data, app_data, leader = get_databags(
        unit_name, endpoint, other_unit_name, other_endpoint, model
    )

    if not include_default_juju_keys:
        purge(unit_data)

    return UnitRelationData(unit_name, endpoint, leader, app_data, unit_data)


def get_databags(local_unit, local_endpoint, remote_unit, remote_endpoint, model):
    """Get the databags of local unit and its leadership status.

    Given a remote unit and the remote endpoint name.
    """
    local_data = get_unit_info(local_unit, model)
    leader = local_data["leader"]

    data = get_unit_info(remote_unit, model)
    relation_info = data.get("relation-info")
    if not relation_info:
        raise RuntimeError(f"{remote_unit} has no relations")

    raw_data = get_relation_by_endpoint(relation_info, local_endpoint, remote_endpoint, local_unit)
    unit_data = raw_data["related-units"][local_unit]["data"]
    app_data = raw_data["application-data"]
    return unit_data, app_data, leader


@dataclass
class RelationData:
    """A dataclass wrapper for the provider/requirer."""

    provider: UnitRelationData
    requirer: UnitRelationData


def get_relation_data(
        *,
        provider_endpoint: str,
        requirer_endpoint: str,
        include_default_juju_keys: bool = False,
        model: str = None,
) -> RelationData:
    """Get relation databags for a juju relation.

    >>> get_relation_data('prometheus/0:ingress', 'traefik/1:ingress-per-unit')
    """
    provider_data = get_content(
        provider_endpoint, requirer_endpoint, include_default_juju_keys, model
    )
    requirer_data = get_content(
        requirer_endpoint, provider_endpoint, include_default_juju_keys, model
    )
    return RelationData(provider=provider_data, requirer=requirer_data)


async def deploy_literal_bundle(ops_test: OpsTest, bundle: str) -> None:
    """Deploy the bundle provided in the parameter using `juju deploy`."""
    run_args = [
        "juju",
        "deploy",
        "--trust",
        "-m",
        ops_test.model_name,
        str(ops_test.render_bundle(bundle)),
    ]

    retcode, stdout, stderr = await ops_test.run(*run_args)
    assert retcode == 0, f"Deploy failed: {(stderr or stdout).strip()}"
    logger.info(stdout)


async def run_command(model_name: str, app_name: str, unit_num: int, command: list) -> bytes:
    """Run a command on a juju unit."""
    cmd = ["juju", "ssh", "--model", model_name, f"{app_name}/{unit_num}", *command]
    try:
        res = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        logger.info(res)
    except subprocess.CalledProcessError as e:
        logger.error(e.stdout.decode())
        raise e
    return res.stdout


async def get_unit_address(ops_test: OpsTest, app_name, unit_no) -> str:
    """Get address of the unit."""
    status = await ops_test.model.get_status()
    app = status["applications"][app_name]
    if app is None:
        assert False, f"no app exists with name {app_name}"
    unit = app["units"].get(f"{app_name}/{unit_no}")
    if unit is None:
        assert False, f"no unit exists in app {app_name} with index {unit_no}"
    return unit["address"]


def deploy_and_configure_minio(model: Optional[str] = None) -> None:
    """Deploy and set up minio and s3-integrator needed for s3-like storage backend in the HA charms.
    :param model:
    """
    juju = Juju(model=model)
    config = {
        "access-key": ACCESS_KEY,
        "secret-key": SECRET_KEY,
    }
    juju.deploy(MINIO, channel="edge", trust=True, config=config)
    juju.wait(
        stop=lambda status: status.workload_status(MINIO)[f"{MINIO}/0"] == WorkloadStatus.active,
        timeout=2000
    )
    minio_addr = juju.status().get_unit_ips(MINIO)[f"{MINIO}/0"]

    # TODO we shouldn't create a bucket here, rather in the HA charm. this should just deploy minio
    create_bucket(minio_addr)

    # configure s3-integrator

    juju.application_config_set(
        S3_APP_NAME,
        {
            "endpoint": f"{MINIO}-0.{MINIO}-endpoints.{model}.svc.cluster.local:9000",
            "bucket": BUCKET_NAME,
        }
    )

    action_result = juju.run(S3_APP_NAME, "sync-s3-credentials", params=config)

    assert action_result["status"] == "completed"


def create_bucket(minio_addr: str, bucket_name: str = BUCKET_NAME):
    mc_client = Minio(
        f"{minio_addr}:9000",
        access_key="accesskey",
        secret_key="secretkey",
        secure=False,
    )
    # create tempo bucket
    found = mc_client.bucket_exists(bucket_name)
    if not found:
        mc_client.make_bucket(bucket_name)


async def get_application_ip(ops_test: OpsTest, app_name: str) -> str:
    """Get the application IP address."""
    status = await ops_test.model.get_status()
    app = status["applications"][app_name]
    return app.public_address
