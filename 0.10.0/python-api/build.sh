#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

exec docker run --rm \
    --network host \
    --user root \
    --volume "${REPOSITORY_ROOT}:/workspace" \
    --workdir /workspace \
    ubuntu:22.04 \
    /workspace/0.10.0/python-api/scripts/build-in-container.sh
