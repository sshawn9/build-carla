#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

configure_build_environment() {
    export PATH="${CARLA_PYTHON_SHIM_DIR}:${PATH}"
    export CARLA_BUILD_NO_COLOR=1
    export CC=clang-10
    export CXX=clang++-10
}

reset_raw_wheel_directory() {
    mkdir -p "${CARLA_RAW_WHEEL_DIR}"
    find "${CARLA_RAW_WHEEL_DIR}" -mindepth 1 -maxdepth 1 \
        \( -name '*.whl' -o -name '*.egg' -o -name '.tmp' \) \
        -exec rm -rf -- {} +
}

setup_carla_dependencies() {
    make -C "${CARLA_SOURCE_DIR}" setup \
        ARGS="--python-version=${CARLA_PYTHON_VERSION_CSV}"
}

build_libcarla_client() {
    "${CARLA_SOURCE_DIR}/Util/BuildTools/BuildLibCarla.sh" --client --release
}

build_osm2odr() {
    "${CARLA_SOURCE_DIR}/Util/BuildTools/BuildOSM2ODR.sh" --build
}

build_python_wheels() {
    # Running the PythonAPI recipe directly avoids a second Setup.sh invocation
    # with CARLA's default single `python3` value.
    # uv's CPython sysconfig contains host-GCC flags that Clang 10 does not
    # support, including -fstack-clash-protection.
    CFLAGS="-O3 -fPIC" \
    CXXFLAGS="-O3 -fPIC" \
        "${CARLA_SOURCE_DIR}/Util/BuildTools/BuildPythonAPI.sh" \
        --clean \
        --build-wheel \
        --python-version="${CARLA_PYTHON_VERSION_CSV}"
}

main() {
    configure_build_environment
    reset_raw_wheel_directory
    setup_carla_dependencies
    build_libcarla_client
    build_osm2odr
    build_python_wheels
}

main "$@"
