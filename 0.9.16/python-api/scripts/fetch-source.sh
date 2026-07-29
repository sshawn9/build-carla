#!/usr/bin/env bash
set -euo pipefail

PATCH_WORKTREE=""
PATCHED_SOURCE_FILES=()

load_build_configuration() {
    local script_dir
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    source "${script_dir}/config.sh"
    PATCH_DIR="${BUILD_CARLA_DIR}/patches"
}

clone_carla_source() {
    git clone \
        --no-checkout \
        --depth 1 \
        --filter=blob:none \
        --branch "${CARLA_VERSION}" \
        --single-branch \
        https://github.com/carla-simulator/carla.git \
        "${CARLA_SOURCE_DIR}"

    # Point HEAD at the tag's peeled commit before enabling sparse checkout so
    # Git populates the index from the commit.
    local carla_commit
    carla_commit="$(git -C "${CARLA_SOURCE_DIR}" rev-parse "${CARLA_VERSION}^{}")"
    git -C "${CARLA_SOURCE_DIR}" update-ref --no-deref HEAD "${carla_commit}"
    git -C "${CARLA_SOURCE_DIR}" sparse-checkout init --cone
    git -C "${CARLA_SOURCE_DIR}" sparse-checkout set LibCarla PythonAPI Util
    git -C "${CARLA_SOURCE_DIR}" read-tree -mu HEAD
}

prepare_carla_source() {
    mkdir -p "${CARLA_WORK_ROOT}"

    if [[ ! -e "${CARLA_SOURCE_DIR}" ]]; then
        clone_carla_source
    fi

    if [[ ! -d "${CARLA_SOURCE_DIR}/.git" ]]; then
        printf 'error: source path is not a Git checkout: %s\n' "${CARLA_SOURCE_DIR}" >&2
        exit 1
    fi

    # A bind-mounted checkout can be owned by the host user. The container is
    # disposable, so registering this one path globally is safe.
    if ! git -C "${CARLA_SOURCE_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
        git config --global --add safe.directory "${CARLA_SOURCE_DIR}"
    fi

    local carla_commit
    local tag_commit
    carla_commit="$(git -C "${CARLA_SOURCE_DIR}" rev-parse HEAD)"
    tag_commit="$(git -C "${CARLA_SOURCE_DIR}" rev-list -n 1 "${CARLA_VERSION}")"

    if [[ "${carla_commit}" != "${tag_commit}" ]]; then
        printf 'error: source checkout is not CARLA %s\n' "${CARLA_VERSION}" >&2
        exit 1
    fi
}

cleanup_patch_worktree() {
    if [[ -n "${PATCH_WORKTREE}" ]]; then
        rm -rf -- "${PATCH_WORKTREE}"
        PATCH_WORKTREE=""
    fi
}

prepare_patch_worktree() {
    mapfile -t PATCHED_SOURCE_FILES < <(
        sed -n 's|^+++ b/||p' "${PATCH_DIR}"/*.patch | sort -u
    )

    PATCH_WORKTREE="$(mktemp -d /tmp/build-carla-patches.XXXXXX)"
    trap cleanup_patch_worktree EXIT

    git -C "${CARLA_SOURCE_DIR}" checkout-index \
        --prefix="${PATCH_WORKTREE}/" \
        -- "${PATCHED_SOURCE_FILES[@]}"
}

apply_carla_patch() {
    local patch_file="${PATCH_DIR}/$1"

    if git -C "${PATCH_WORKTREE}" apply "${patch_file}"; then
        return
    fi

    printf 'error: patch does not apply cleanly: %s\n' "${patch_file##*/}" >&2
    exit 1
}

install_patched_source_files() {
    local source_file

    for source_file in "${PATCHED_SOURCE_FILES[@]}"; do
        cp --preserve=mode -- \
            "${PATCH_WORKTREE}/${source_file}" \
            "${CARLA_SOURCE_DIR}/${source_file}"
    done

    cleanup_patch_worktree
}

apply_disable_libcarla_unit_tests_patch() {
    apply_carla_patch carla-0.9.16-disable-libcarla-unit-tests.patch
}

apply_ubuntu_20_04_toolchain_patch() {
    apply_carla_patch carla-0.9.16-use-ubuntu-20.04-toolchain.patch
}

apply_carla_client_version_patch() {
    apply_carla_patch carla-0.9.16-set-client-version.patch
}

apply_dependency_download_urls_patch() {
    apply_carla_patch carla-0.9.16-fix-libpng-download-url.patch
}

apply_boost_source_archive_reuse_patch() {
    apply_carla_patch carla-0.9.16-reuse-boost-source-archive.patch
}

apply_proj_pic_patch() {
    apply_carla_patch carla-0.9.16-build-proj-with-pic.patch
}

apply_patchelf_0_19_1_upgrade_patch() {
    apply_carla_patch carla-0.9.16-upgrade-patchelf-to-0.19.1.patch
}

apply_python_distribution_metadata_patch() {
    apply_carla_patch carla-0.9.16-use-python-distribution-metadata.patch
}

apply_prepared_python_build_environment_patch() {
    apply_carla_patch carla-0.9.16-use-prepared-python-build-environment.patch
}

copy_python_distribution_files() {
    cp \
        "${BUILD_CARLA_DIR}/distribution.json" \
        "${CARLA_SOURCE_DIR}/PythonAPI/carla/distribution.json"
    cp \
        "${CARLA_SOURCE_DIR}/LICENSE" \
        "${CARLA_SOURCE_DIR}/PythonAPI/carla/LICENSE"
}

apply_osm2odr_client_only_patch() {
    apply_carla_patch carla-0.9.16-build-osm2odr-client-only.patch
}

apply_skip_server_dependency_builds_patch() {
    apply_carla_patch carla-0.9.16-skip-server-dependency-builds.patch
}

show_carla_source_changes() {
    git -C "${CARLA_SOURCE_DIR}" diff --stat
}

main() {
    load_build_configuration
    prepare_carla_source
    prepare_patch_worktree

    apply_disable_libcarla_unit_tests_patch
    apply_ubuntu_20_04_toolchain_patch
    apply_carla_client_version_patch
    apply_dependency_download_urls_patch
    apply_boost_source_archive_reuse_patch
    apply_proj_pic_patch
    apply_patchelf_0_19_1_upgrade_patch
    apply_python_distribution_metadata_patch
    apply_prepared_python_build_environment_patch

    # Enabled client-only build optimizations:
    apply_osm2odr_client_only_patch
    apply_skip_server_dependency_builds_patch
    # The server-dependency patch requires the OSM2ODR client-only patch.

    install_patched_source_files
    copy_python_distribution_files
    show_carla_source_changes
}

main "$@"
