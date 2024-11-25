# Copyright 2024 Canonical Ltd.
# See LICENSE file for licensing details.

"""A set of common functions used for deploying tempo useful in integration tests."""

import json
import logging
import os
from pathlib import Path
from typing import Optional

import requests
from pytest_operator.plugin import OpsTest
from tenacity import retry, stop_after_attempt, wait_exponential

from .common import S3_INTEGRATOR, deploy_and_configure_minio, S3_APP_NAME
from .juju import Juju, WorkloadStatus

WORKER_NAME = "tempo-worker"
APP_NAME = "tempo"
protocols_endpoints = {
    "jaeger_thrift_http": "https://{}:14268/api/traces?format=jaeger.thrift",
    "zipkin": "https://{}:9411/v1/traces",
    "jaeger_grpc": "{}:14250",
    "otlp_http": "https://{}:4318/v1/traces",
    "otlp_grpc": "{}:4317",
}

logger = logging.getLogger(__name__)



def tempo_coordinator_charm_and_channel():
    """Tempo coordinator charm used for integration testing.

    Build once per session and reuse it in all integration tests to save some minutes/hours.
    You can also set `TEMPO_COORDINATOR_CHARM` env variable to use an already existing built charm.
    """
    if path_from_env := os.getenv("TEMPO_COORDINATOR_CHARM"):
        return Path(path_from_env).absolute(), None
    return "tempo-coordinator-k8s", "edge"


def tempo_worker_charm_and_channel():
    """Tempo worker charm used for integration testing.

    Build once per session and reuse it in all integration tests to save some minutes/hours.
    You can also set `TEMPO_WORKER_CHARM` env variable to use an already existing built charm.
    """
    if path_from_env := os.getenv("TEMPO_WORKER_CHARM"):
        return Path(path_from_env).absolute(), None
    return "tempo-worker-k8s", "edge"


async def deploy_tempo_cluster(model: Optional[str] = None, tempo_app: str = APP_NAME):
    """Deploys tempo in its HA version together with minio and s3-integrator."""

    juju = Juju(model=model)
    tempo_worker_charm_url, worker_channel = tempo_worker_charm_and_channel()
    tempo_coordinator_charm_url, coordinator_channel = tempo_coordinator_charm_and_channel()
    juju.deploy(tempo_worker_charm_url, alias=WORKER_NAME, channel=worker_channel, trust=True)
    juju.deploy(
        tempo_coordinator_charm_url,
        alias=tempo_app,
        channel=coordinator_channel,
        trust=True,
    )
    # TODO minio deployment should be extracted so that more than 1 HA charm can use the same minio instance
    # then tempo_cluster would deploy its own s3_integrator and create the required bucket (prob via calling a common method)
    juju.deploy(S3_INTEGRATOR, alias=S3_APP_NAME, channel="edge")

    juju.integrate(tempo_app + ":s3", S3_APP_NAME + ":s3-credentials")
    juju.integrate(tempo_app + ":tempo-cluster", WORKER_NAME + ":tempo-cluster")

    deploy_and_configure_minio(model)
    juju.wait(
        stop=lambda status: status.all_workloads([tempo_app, WORKER_NAME, S3_INTEGRATOR], WorkloadStatus.active),
        timeout=2000,
        soak=30,
    )


def get_traces(tempo_host: str, service_name="tracegen-otlp_http", tls=True):
    """Get traces directly from Tempo REST API."""
    url = f"{'https' if tls else 'http'}://{tempo_host}:3200/api/search?tags=service.name={service_name}"
    req = requests.get(
        url,
        verify=False,
    )
    assert req.status_code == 200
    traces = json.loads(req.text)["traces"]
    return traces


@retry(stop=stop_after_attempt(15), wait=wait_exponential(multiplier=1, min=4, max=10))
async def get_traces_patiently(tempo_host, service_name="tracegen-otlp_http", tls=True):
    """Get traces directly from Tempo REST API, but also try multiple times.

    Useful for cases when Tempo might not return the traces immediately (its API is known for returning data in
    random order).
    """
    traces = get_traces(tempo_host, service_name=service_name, tls=tls)
    assert len(traces) > 0
    return traces
