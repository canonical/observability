#!/bin/bash

set -euo pipefail

# Variables
MODEL_NAME=""
MINIO_APP=""
MC_BINARY_URL=""
MINIO_URL=""
MINIO_USER=""
MINIO_PASSWORD=""
LOKI_BUCKET=""
MIMIR_BUCKET=""
TEMPO_BUCKET=""
LOKI_INTEGRATOR=""
MIMIR_INTEGRATOR=""
TEMPO_INTEGRATOR=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --model-name) MODEL_NAME="$2"; shift ;;
    --minio-app) MINIO_APP="$2"; shift ;;
    --mc-binary-url) MC_BINARY_URL="$2"; shift ;;
    --minio-url) MINIO_URL="$2"; shift ;;
    --minio-user) MINIO_USER="$2"; shift ;;
    --minio-password) MINIO_PASSWORD="$2"; shift ;;
    --loki-bucket) LOKI_BUCKET="$2"; shift ;;
    --mimir-bucket) MIMIR_BUCKET="$2"; shift ;;
    --tempo-bucket) TEMPO_BUCKET="$2"; shift ;;
    --loki-integrator) LOKI_INTEGRATOR="$2"; shift ;;
    --mimir-integrator) MIMIR_INTEGRATOR="$2"; shift ;;
    --tempo-integrator) TEMPO_INTEGRATOR="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

# Functions
wait_for_app() {
  local app="$1"
  echo "Waiting for application $app in model $MODEL_NAME..."
  juju wait-for application "$app" -m "$MODEL_NAME" --timeout 20m
}

configure_s3() {
  local bucket_name="$1"
  local integrator="$2"

  echo "Creating bucket $bucket_name..."
  juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" /root/minio/mc mb local/"$bucket_name"

  echo "Configuring $integrator..."
  juju config "$integrator" endpoint="$MINIO_URL" bucket="$bucket_name"

  echo "Syncing S3 credentials for $integrator..."
  juju run -m "$MODEL_NAME" "$integrator/leader" sync-s3-credentials access-key="$MINIO_USER" secret-key="$MINIO_PASSWORD"
}

# Main execution
echo "Downloading MinIO client..."
juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" curl "$MC_BINARY_URL" --create-dirs -o '/root/minio/mc'
juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" chmod +x '/root/minio/mc'
juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" /root/minio/mc alias set local "$MINIO_URL" "$MINIO_USER" "$MINIO_PASSWORD"

# Wait for MinIO app
wait_for_app "$MINIO_APP"

# Configure buckets and sync credentials
configure_s3 "$LOKI_BUCKET" "$LOKI_INTEGRATOR"
configure_s3 "$MIMIR_BUCKET" "$MIMIR_INTEGRATOR"
configure_s3 "$TEMPO_BUCKET" "$TEMPO_INTEGRATOR"

echo "S3 configuration complete!"
