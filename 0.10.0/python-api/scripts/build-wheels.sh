#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

DEPENDENCY_SOURCE_ARGUMENTS=()

configure_build_environment() {
    export PATH="${CARLA_BUILD_TOOLS_VENV}/bin:${PATH}"
    export CC=gcc-12
    export CXX=g++-12
}

reset_raw_wheel_directory() {
    rm -rf "${CARLA_RAW_WHEEL_DIR}"
    mkdir -p "${CARLA_RAW_WHEEL_DIR}" "${CARLA_CMAKE_BUILD_ROOT}"
}

collect_dependency_source_arguments() {
    local version="$1"
    local dependency
    local dependency_source
    local seed_build_dir="${CARLA_CMAKE_BUILD_ROOT}/python-${CARLA_PYTHON_VERSIONS[0]}"
    local seed_dependency_dir="${seed_build_dir}/_deps"

    DEPENDENCY_SOURCE_ARGUMENTS=()
    if [[ "${version}" == "${CARLA_PYTHON_VERSIONS[0]}" ]]; then
        return
    fi

    for dependency in sqlite3 zlib libpng boost eigen rpclib recastnavigation; do
        dependency_source="${seed_dependency_dir}/${dependency}-src"
        if [[ -d "${dependency_source}" ]]; then
            DEPENDENCY_SOURCE_ARGUMENTS+=(
                "-DFETCHCONTENT_SOURCE_DIR_${dependency^^}=${dependency_source}"
            )
        fi
    done
}

configure_python_build() {
    local version="$1"
    local managed_python="$2"
    local build_dir="${CARLA_CMAKE_BUILD_ROOT}/python-${version}"
    local python_root="${managed_python%/bin/*}"

    collect_dependency_source_arguments "${version}"
    cmake \
        --fresh \
        -S "${CARLA_SOURCE_DIR}" \
        -B "${build_dir}" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=gcc-12 \
        -DCMAKE_CXX_COMPILER=g++-12 \
        -DGCC_COMPILER=/usr/bin/gcc-12 \
        -DGXX_COMPILER=/usr/bin/g++-12 \
        -DPython_ROOT_DIR="${python_root}" \
        -DPython3_ROOT_DIR="${python_root}" \
        -DPython3_EXECUTABLE="${managed_python}" \
        -DBUILD_CARLA_CLIENT=ON \
        -DBUILD_CARLA_SERVER=OFF \
        -DBUILD_CARLA_UNREAL=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_LIBCARLA_TESTS=OFF \
        -DBUILD_PYTHON_API=ON \
        -DINSTALL_LIBCARLA=OFF \
        -DENABLE_OSM2ODR=OFF \
        -DENABLE_PYTORCH=OFF \
        -DENABLE_ROS2=OFF \
        -DENABLE_ROS2_DEMO=OFF \
        -DENABLE_RSS=OFF \
        -DENABLE_STREETMAP=OFF \
        -DBUILD_OSM_WORLD_RENDERER=OFF \
        -DPREFER_CLONE=OFF \
        -DENABLE_PEP517=ON \
        "${DEPENDENCY_SOURCE_ARGUMENTS[@]}"
}

build_python_wheel() {
    local version="$1"
    local build_dir="${CARLA_CMAKE_BUILD_ROOT}/python-${version}"
    local package_dir="${CARLA_PYTHON_PACKAGE_ROOT}/python-${version}"
    local build_dist_dir="${build_dir}/PythonAPI/dist"

    rm -rf "${build_dist_dir}"
    PYTHONNOUSERSITE=1 \
    PYTHONPATH="${package_dir}" \
        cmake --build "${build_dir}" --target carla-python-api
    cp "${build_dist_dir}/"*.whl "${CARLA_RAW_WHEEL_DIR}/"
}

build_python_versions() {
    local managed_python
    local version

    for version in "${CARLA_PYTHON_VERSIONS[@]}"; do
        managed_python="$(uv python find --managed-python "${version}")"
        configure_python_build "${version}" "${managed_python}"
        build_python_wheel "${version}"
    done
}

main() {
    configure_build_environment
    reset_raw_wheel_directory
    build_python_versions
}

main "$@"
