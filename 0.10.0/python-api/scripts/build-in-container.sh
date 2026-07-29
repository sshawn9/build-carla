#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

workspace_owner="$(stat -c '%u:%g' "${REPOSITORY_ROOT}")"

restore_ownership() {
    for path in "${CARLA_WORK_ROOT}" "${BUILD_CARLA_DIR}/dist"; do
        if [[ -e "${path}" ]]; then
            chown -R "${workspace_owner}" "${path}" || true
        fi
    done
}
trap restore_ownership EXIT

"${SCRIPT_DIR}/install-dependencies.sh"
curl -LsSf https://astral.sh/uv/install.sh |
    env UV_UNMANAGED_INSTALL=/usr/local/bin sh
uv --version
"${SCRIPT_DIR}/prepare-python.sh"
"${SCRIPT_DIR}/fetch-source.sh"
"${SCRIPT_DIR}/build-wheels.sh"
"${SCRIPT_DIR}/repair-wheels.sh"
"${SCRIPT_DIR}/write-metadata.sh"
