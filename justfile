set quiet  # Recipes are silent by default
set export  # Just variables are exported to the environment

mod utils

[private]
default:
  just --list

# Lint everything
[group("dev")]
lint:
  # Lint the GitHub workflows
  uvx --from=actionlint-py actionlint

# List unarchived repos for one or more GitHub teams
[group("info")]
list-repos +teams:
  #!/usr/bin/env bash
  for team in {{teams}}; do
    gh api "orgs/canonical/teams/${team}/repos" --paginate \
      | jq -r '.[] | select(.archived == false and .disabled == false) | .full_name'
  done | sort -u

# List all charms for the Observability team
[group("info")]
list-charms:
  #!/usr/bin/env bash
  charms=(
    # Observability Core
    "alertmanager-k8s"
    "avalanche-k8s"
    "blackbox-exporter"
    "blackbox-exporter-k8s"
    "catalogue-k8s"
    "cos-configuration-k8s"
    "cos-proxy"
    "grafana-k8s"
    "loki-coordinator-k8s"
    "loki-k8s"
    "loki-worker-k8s"
    "mimir-coordinator-k8s"
    "mimir-worker-k8s"
    "opentelemetry-collector"
    "opentelemetry-collector-k8s"
    "otelcol-integrator"
    "prometheus-k8s"
    "prometheus-pushgateway-k8s"
    "prometheus-scrape-config-k8s"
    "prometheus-scrape-target-k8s"
    "script-exporter"
    "snmp-exporter"

    # Tracing & Profiling
    "k6-k8s"
    "litmus-auth-k8s"
    "litmus-backend-k8s"
    "litmus-chaoscenter-k8s"
    "litmus-infrastructure-k8s"
    "otel-ebpf-profiler"
    "parca-agent"
    "parca-k8s"
    "parca-scrape-target"
    "polar-signals-cloud-integrator"
    "pyroscope-coordinator-k8s"
    "pyroscope-worker-k8s"
    "tempo-coordinator-k8s"
    "tempo-worker-k8s"

    # Service Mesh
    "grafana-agent"
    "grafana-agent-k8s"
    "grafana-cloud-integrator"
    "istio-beacon-k8s"
    "istio-ingress-k8s"
    "istio-k8s"
    "kiali-k8s"

  )
  printf '%s\n' "${charms[@]}"

# Promote a charm through all non-dev/non-latest tracks (beta→candidate, edge→beta)
[group("maintenance")]
promote-train charm:
  #!/usr/bin/env bash
  set -euo pipefail
  tracks=$(juju info {{charm}} --format=json | jq -r '.tracks[]')
  for track in $tracks; do
    if [[ "$track" == "dev" || "$track" == "latest" ]]; then
      continue
    fi
    echo "Promoting {{charm}} on track ${track}..."
    # FIXME: We're shortcircuiting this until we have quality gates in place, so that `/edge` goes directly to `/candidate`
    # charmcraft promote --yes --name "{{charm}}" --from-channel="${track}/beta" --to-channel="${track}/candidate"
    # charmcraft promote --yes --name "{{charm}}" --from-channel="${track}/edge" --to-channel="${track}/beta"
    charmcraft promote --yes --name "{{charm}}" --from-channel="${track}/edge" --to-channel="${track}/beta"
    charmcraft promote --yes --name "{{charm}}" --from-channel="${track}/edge" --to-channel="${track}/candidate"
  done
