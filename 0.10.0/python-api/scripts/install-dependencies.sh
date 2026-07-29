#!/usr/bin/env bash
set -euo pipefail

apt-get update
# tzdata is pulled in transitively; do not let it prompt in the container.
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    file \
    g++-12 \
    gcc-12 \
    git \
    jq \
    ninja-build \
    patchelf \
    unzip \
    xz-utils
