#!/usr/bin/env bash
set -euo pipefail

apt-get update
# tzdata is pulled in transitively; do not let it prompt in the container.
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    curl \
    file \
    git \
    jq \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libc++-dev \
    libc++abi-dev \
    libtool \
    libxml2-dev \
    lld \
    ninja-build \
    rsync \
    unzip \
    wget \
    xz-utils \
    zlib1g-dev
