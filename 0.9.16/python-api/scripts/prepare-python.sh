#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

create_python_directories() {
    mkdir -p \
        "${CARLA_WORK_ROOT}" \
        "${CARLA_PYTHON_PACKAGE_ROOT}" \
        "${CARLA_PYTHON_SHIM_DIR}"
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
        "distro==${CARLA_DISTRO_VERSION}" \
        "setuptools==${CARLA_SETUPTOOLS_VERSION}" \
        "wheel==${CARLA_WHEEL_VERSION}"
}

create_python_shim() {
    local version="$1"
    local managed_python="$2"
    local package_dir="${CARLA_PYTHON_PACKAGE_ROOT}/python-${version}"
    local shim="${CARLA_PYTHON_SHIM_DIR}/python${version}"

    {
        printf '#!/usr/bin/env bash\n'
        printf 'set -euo pipefail\n'
        printf 'export PYTHONNOUSERSITE=1\n'
        printf 'export PYTHONPATH=%q\n' "${package_dir}"
        printf 'exec %q "$@"\n' "${managed_python}"
    } >"${shim}"
    chmod +x "${shim}"
}

prepare_python_version() {
    local version="$1"
    local managed_python
    managed_python="$(uv python find --managed-python "${version}")"

    install_python_build_packages "${version}" "${managed_python}"
    create_python_shim "${version}" "${managed_python}"
}

prepare_python_versions() {
    local version

    for version in "${CARLA_PYTHON_VERSIONS[@]}"; do
        prepare_python_version "${version}"
    done
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
    prepare_auditwheel_environment
}

main "$@"
