#!/bin/bash

set -euo pipefail

# Variables
MODEL_NAME=""
MINIO_APP=""
MC_BINARY_URL=""
MINIO_URL=""
MINIO_USER="${MINIO_USER:-}"
MINIO_PASSWORD="${MINIO_PASSWORD:-}"
LOKI_BUCKET=""
MIMIR_BUCKET=""
TEMPO_BUCKET=""
LOKI_INTEGRATOR=""
MIMIR_INTEGRATOR=""
TEMPO_INTEGRATOR=""

MC_BINARY="/root/minio/mc"

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

# Credentials validation
if [[ -z "$MINIO_USER" || -z "$MINIO_PASSWORD" ]]; then
  echo "Error: MINIO_USER and MINIO_PASSWORD must be set either as arguments or environment variables."
  exit 1
fi


# Functions
wait_for_app() {
  local app="$1"
  local status="${2:-active}"

  echo "Waiting for application $app in model $MODEL_NAME..."
  juju wait-for application "$app" -m "$MODEL_NAME" --query="status=='$status'" --timeout 20m
}

bucket_exists() {
  local bucket_name="$1"
  juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" "$MC_BINARY" ls local/ | grep -q "$bucket_name"
}

mc_exists() {
  echo "Checking if mc is already downlaoded..."
  juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" ls "$MC_BINARY"
}

configure_s3() {
  local bucket_name="$1"
  local integrator="$2"


  echo "Checking if bucket $bucket_name exists..."
  if bucket_exists "$bucket_name"; then
    echo "Bucket $bucket_name already exists. Skipping creation."
  else
    echo "Creating bucket $bucket_name..."
    juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" "$MC_BINARY" mb local/"$bucket_name"
  fi

  wait_for_app "$integrator" "blocked"

  echo "Configuring $integrator..."
  juju config "$integrator" endpoint="$MINIO_URL" bucket="$bucket_name"

  echo "Syncing S3 credentials for $integrator..."
  juju run -m "$MODEL_NAME" "$integrator/leader" sync-s3-credentials access-key="$MINIO_USER" secret-key="$MINIO_PASSWORD"
}

configure_minio() {
  # Wait for MinIO app
  wait_for_app "$MINIO_APP"

  if mc_exists; then
    echo "MinIO client is already downloaded. Skipping download."
  else
    echo "Downloading MinIO client..."
    juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" curl "$MC_BINARY_URL" --create-dirs -o "$MC_BINARY"
  fi

  juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" chmod +x "$MC_BINARY"
  juju ssh -m "$MODEL_NAME" "$MINIO_APP/leader" "$MC_BINARY" alias set local "$MINIO_URL" "$MINIO_USER" "$MINIO_PASSWORD"
}

# Configure MinIO
configure_minio

# Configure buckets and sync credentials
configure_s3 "$LOKI_BUCKET" "$LOKI_INTEGRATOR"
configure_s3 "$MIMIR_BUCKET" "$MIMIR_INTEGRATOR"
configure_s3 "$TEMPO_BUCKET" "$TEMPO_INTEGRATOR"

echo "S3 configuration complete!"
