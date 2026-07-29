#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_IMAGE="sshawn/carla-python-api-builder:0.9.16"

exec docker build --network host \
    --tag "${BUILDER_IMAGE}" \
    "${SCRIPT_DIR}"
