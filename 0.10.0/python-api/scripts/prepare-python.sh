#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

create_python_directories() {
    mkdir -p \
        "${CARLA_WORK_ROOT}" \
        "${CARLA_PYTHON_PACKAGE_ROOT}"
}

install_python_runtimes() {
    uv python install \
        --managed-python \
        --no-bin \
        "${CARLA_PYTHON_VERSIONS[@]}"
}

install_python_build_packages() {
    local version="$1"
    local managed_python="$2"
    local package_dir="${CARLA_PYTHON_PACKAGE_ROOT}/python-${version}"

    rm -rf "${package_dir}"
    mkdir -p "${package_dir}"
    uv pip install \
        --python "${managed_python}" \
        --target "${package_dir}" \
        "build==${CARLA_BUILD_VERSION}" \
        "scikit-build-core==${CARLA_SCIKIT_BUILD_CORE_VERSION}" \
        "wheel==${CARLA_WHEEL_VERSION}"
}

prepare_python_versions() {
    local managed_python
    local version

    for version in "${CARLA_PYTHON_VERSIONS[@]}"; do
        managed_python="$(uv python find --managed-python "${version}")"
        install_python_build_packages "${version}" "${managed_python}"
    done
}

prepare_build_tools() {
    local tools_python
    tools_python="$(uv python find --managed-python "${CARLA_BUILD_TOOLS_PYTHON_VERSION}")"

    rm -rf "${CARLA_BUILD_TOOLS_VENV}"
    uv venv --python "${tools_python}" "${CARLA_BUILD_TOOLS_VENV}"
    uv pip install \
        --python "${CARLA_BUILD_TOOLS_VENV}/bin/python" \
        "cmake==${CARLA_CMAKE_VERSION}"
}

prepare_auditwheel_environment() {
    local auditwheel_python
    auditwheel_python="$(uv python find --managed-python "${CARLA_AUDITWHEEL_PYTHON_VERSION}")"

    rm -rf "${CARLA_AUDITWHEEL_VENV}"
    uv venv --python "${auditwheel_python}" "${CARLA_AUDITWHEEL_VENV}"
    uv pip install \
        --python "${CARLA_AUDITWHEEL_VENV}/bin/python" \
        "auditwheel==${CARLA_AUDITWHEEL_VERSION}"
}

main() {
    create_python_directories
    install_python_runtimes
    prepare_python_versions
    prepare_build_tools
    prepare_auditwheel_environment
}

main "$@"
