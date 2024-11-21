# Copyright 2024 Canonical Ltd.
# See LICENSE file for licensing details.

"""A set of common functions used for deploying tempo useful in integration tests."""

import json
import logging
import os
from pathlib import Path

import requests
from pytest_operator.plugin import OpsTest
from tenacity import retry, stop_after_attempt, wait_exponential

from .common import S3_INTEGRATOR, deploy_and_configure_minio

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


async def deploy_tempo_cluster(ops_test: OpsTest, tempo_app=APP_NAME):
    """Deploys tempo in its HA version together with minio and s3-integrator."""
    tempo_worker_charm_url, worker_channel = tempo_worker_charm_and_channel()
    tempo_coordinator_charm_url, coordinator_channel = tempo_coordinator_charm_and_channel()
    await ops_test.model.deploy(
        tempo_worker_charm_url, application_name=WORKER_NAME, channel=worker_channel, trust=True
    )
    await ops_test.model.deploy(
        tempo_coordinator_charm_url,
        application_name=tempo_app,
        channel=coordinator_channel,
        trust=True,
    )
    await ops_test.model.deploy(S3_INTEGRATOR, channel="edge")

    await ops_test.model.integrate(tempo_app + ":s3", S3_INTEGRATOR + ":s3-credentials")
    await ops_test.model.integrate(tempo_app + ":tempo-cluster", WORKER_NAME + ":tempo-cluster")

    await deploy_and_configure_minio(ops_test)
    async with ops_test.fast_forward():
        await ops_test.model.wait_for_idle(
            apps=[tempo_app, WORKER_NAME, S3_INTEGRATOR],
            status="active",
            timeout=2000,
            idle_period=30,
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
