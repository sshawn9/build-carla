#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

configure_repair_environment() {
    local patchelf_dir="${CARLA_PATCHELF_PATH%/*}"

    # auditwheel invokes patchelf by name.
    export PATH="${patchelf_dir}:${PATH}"
}

reset_output_directory() {
    mkdir -p "${CARLA_OUTPUT_DIR}"
    find "${CARLA_OUTPUT_DIR}" -mindepth 1 -maxdepth 1 -type f \
        \( -name '*.whl' -o -name 'build-manifest-*.json' -o -name SHA256SUMS -o -name LICENSE-CARLA.txt \) \
        -delete
}

repair_raw_wheels() {
    local auditwheel_python="${CARLA_AUDITWHEEL_VENV}/bin/python"
    local raw_wheel
    local raw_wheels=("${CARLA_RAW_WHEEL_DIR}"/*.whl)

    for raw_wheel in "${raw_wheels[@]}"; do
        "${auditwheel_python}" -m auditwheel repair \
            --plat "${CARLA_WHEEL_PLATFORM}" \
            --wheel-dir "${CARLA_OUTPUT_DIR}" \
            "${raw_wheel}"
    done
}

find_repaired_wheel() {
    local version="$1"
    local python_tag="cp${version//./}"
    local matching=("${CARLA_OUTPUT_DIR}"/*-"${python_tag}"-"${python_tag}"-*.whl)

    [[ ${#matching[@]} -eq 1 ]] || return 1
    printf '%s\n' "${matching[0]}"
}

reset_verification_directory() {
    rm -rf "${CARLA_VERIFY_ROOT}"
    mkdir -p "${CARLA_VERIFY_ROOT}"
}

verify_repaired_wheel() {
    local version="$1"
    local python_tag="cp${version//./}"
    local repaired_wheel
    local managed_python
    local verify_venv="${CARLA_VERIFY_ROOT}/${python_tag}"

    repaired_wheel="$(find_repaired_wheel "${version}")"
    managed_python="$(uv python find --managed-python "${version}")"
    uv venv --python "${managed_python}" "${verify_venv}"
    uv pip install \
        --python "${verify_venv}/bin/python" \
        --no-deps \
        "${repaired_wheel}"
    "${verify_venv}/bin/python" - "${CARLA_VERSION}" <<'PY'
import carla
import sys

client_version = carla.Client("127.0.0.1", 2000).get_client_version()
assert client_version == sys.argv[1], client_version
location = carla.Location(x=1.0, y=2.0, z=3.0)
assert (location.x, location.y, location.z) == (1.0, 2.0, 3.0)
PY
    rm -rf "${verify_venv}"
}

verify_repaired_wheels() {
    local version

    reset_verification_directory
    for version in "${CARLA_PYTHON_VERSIONS[@]}"; do
        verify_repaired_wheel "${version}"
    done
    rmdir "${CARLA_VERIFY_ROOT}"
}

main() {
    shopt -s nullglob
    configure_repair_environment
    reset_output_directory
    repair_raw_wheels
    verify_repaired_wheels
}

main
