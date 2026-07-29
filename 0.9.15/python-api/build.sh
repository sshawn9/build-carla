#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

exec docker run --rm \
    --user root \
    --volume "${REPOSITORY_ROOT}:/workspace" \
    --workdir /workspace \
    ubuntu:20.04 \
    /workspace/0.9.15/python-api/scripts/build-in-container.sh
