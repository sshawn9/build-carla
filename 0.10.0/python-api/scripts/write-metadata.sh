#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

build_metadata=

collect_build_metadata() {
    local carla_commit
    local cmake_version
    local compiler
    local distribution_metadata
    local glibc_version
    local patchelf_version
    local requested_python_versions
    local source_diff_sha256
    local uv_version

    carla_commit="$(git -C "${CARLA_SOURCE_DIR}" rev-parse HEAD)"
    source_diff_sha256="$(git -C "${CARLA_SOURCE_DIR}" diff --binary HEAD | sha256sum | awk '{print $1}')"
    compiler="$(g++-12 --version)"
    compiler="${compiler%%$'\n'*}"
    cmake_version="$(cmake --version | awk 'NR == 1 {print $3}')"
    glibc_version="$(getconf GNU_LIBC_VERSION | awk '{print $2}')"
    patchelf_version="$("${CARLA_PATCHELF_PATH}" --version | awk '{print $2}')"
    uv_version="$(uv --version | awk '{print $2}')"
    distribution_metadata="$(jq -c . "${BUILD_CARLA_DIR}/distribution.json")"
    requested_python_versions="$(jq -cn --args '$ARGS.positional' "${CARLA_PYTHON_VERSIONS[@]}")"

    build_metadata="$(jq -cn \
        --arg carla_version "${CARLA_VERSION}" \
        --arg carla_commit "${carla_commit}" \
        --arg source_diff_sha256 "${source_diff_sha256}" \
        --arg platform "${CARLA_WHEEL_PLATFORM}" \
        --arg compiler "${compiler}" \
        --arg cmake_version "${cmake_version}" \
        --arg glibc_version "${glibc_version}" \
        --arg patchelf_version "${patchelf_version}" \
        --arg uv_version "${uv_version}" \
        --argjson distribution "${distribution_metadata}" \
        --argjson requested_python_versions "${requested_python_versions}" \
        --arg build_version "${CARLA_BUILD_VERSION}" \
        --arg scikit_build_core_version "${CARLA_SCIKIT_BUILD_CORE_VERSION}" \
        --arg wheel_version "${CARLA_WHEEL_VERSION}" \
        --arg auditwheel_version "${CARLA_AUDITWHEEL_VERSION}" \
        '{
            carla_version: $carla_version,
            carla_commit: $carla_commit,
            source_diff_sha256: $source_diff_sha256,
            platform: $platform,
            compiler: $compiler,
            cmake_version: $cmake_version,
            glibc_version: $glibc_version,
            patchelf_version: $patchelf_version,
            uv_version: $uv_version,
            distribution: $distribution,
            python_build: {
                requested_python_versions: $requested_python_versions,
                build_packages: {
                    build: $build_version,
                    scikit_build_core: $scikit_build_core_version,
                    wheel: $wheel_version,
                    auditwheel: $auditwheel_version
                }
            }
        }')"
}

copy_carla_license() {
    cp "${CARLA_SOURCE_DIR}/LICENSE" "${CARLA_OUTPUT_DIR}/LICENSE-CARLA.txt"
}

write_manifest() {
    local version="$1"
    local metadata="$2"
    local python_tag="cp${version//./}"
    local managed_python
    local resolved_python_version

    managed_python="$(uv python find --managed-python "${version}")"
    resolved_python_version="$("${managed_python}" -c 'import platform; print(platform.python_version())')"

    jq -n \
        --argjson build_metadata "${metadata}" \
        --arg python_version "${version}" \
        --arg resolved_python_version "${resolved_python_version}" \
        '$build_metadata + {
            python_version: $python_version,
            resolved_python_version: $resolved_python_version
        }' >"${CARLA_OUTPUT_DIR}/build-manifest-${python_tag}.json"
}

write_manifests() {
    local metadata="$1"
    local version

    for version in "${CARLA_PYTHON_VERSIONS[@]}"; do
        write_manifest "${version}" "${metadata}"
    done
}

write_wheel_checksums() {
    (
        cd "${CARLA_OUTPUT_DIR}"
        sha256sum ./*.whl >SHA256SUMS
    )
}

main() {
    export PATH="${CARLA_BUILD_TOOLS_VENV}/bin:${PATH}"
    collect_build_metadata
    copy_carla_license
    write_manifests "${build_metadata}"
    write_wheel_checksums
}

main "$@"
