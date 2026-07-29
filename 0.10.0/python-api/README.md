# CARLA 0.10.0 Python wheels

This directory builds CARLA 0.10.0 client wheels for CPython 3.10 through
3.14. CARLA 0.10.0 replaced the old `Util/BuildTools` pipeline with CMake and
scikit-build-core, so this version has a separate build implementation instead
of inheriting the 0.9.x scripts.

The build runs in Ubuntu 22.04 with GCC 12 and CMake 3.28.3, matching the
toolchain generation used by CARLA 0.10.0. Wheels are repaired for
`manylinux_2_35_x86_64`.

`distribution.json` fixes the independent PyPI distribution metadata. Current
output filenames follow this pattern:

```text
carla_0_10_0-0.0.1-cp<ABI>-cp<ABI>-manylinux_2_35_x86_64.whl
```

The distribution is installed as `carla-0-10-0`; the compiled module and import
remain `carla`, and the client reports CARLA version `0.10.0`.

## Build

Docker and an x86-64 Linux host are required:

```bash
./0.10.0/python-api/build.sh
```

The command has no options. Fixed versions and paths live in
`scripts/config.sh`. Final wheels and metadata are written to `dist/wheels/`;
persistent source, dependency sources, CMake builds, Python runtimes, and
downloads remain under `.work/`.

## Build flow

```text
build.sh
└── Ubuntu 22.04 container
    └── scripts/build-in-container.sh
        ├── install-dependencies.sh  GCC 12, Ninja, patchelf, and base tools
        ├── Astral uv installer      Python runtime installer
        ├── prepare-python.sh        CPython, CMake 3.28.3, and Python packages
        ├── fetch-source.sh          sparse CARLA checkout and source patches
        ├── build-wheels.sh          one client-only CMake build per Python ABI
        ├── repair-wheels.sh         auditwheel repair and import checks
        └── write-metadata.sh        manifests, checksums, and license
```

The independent Dockerfile flow builds an image containing the finished build:

```bash
./0.10.0/python-api/build-docker.sh
```

## Verify release artifacts

Run these commands from the repository root before uploading the wheels:

```bash
cd 0.10.0/python-api
(cd dist/wheels && sha256sum -c SHA256SUMS)
uvx twine check dist/wheels/*.whl
```

`SHA256SUMS` contains paths relative to `dist/wheels`, so its check must run
with that directory as the working directory.

## Fixed CMake scope

Only the CARLA client and Python API are enabled. The server, Unreal project,
examples, tests, ROS 2, RSS, PyTorch, OSM world renderer, and OSM2ODR are fixed
off. `ENABLE_OSM2ODR` remains off because CARLA 0.10.0 itself defaults it off
and the 0.10.0 source tree no longer contains the OSM2ODR implementation that
0.9.x built from SUMO.

The first Python build downloads the seven common FetchContent source trees.
Later Python builds reuse those source directories while keeping independent
binary directories, so Python-specific Boost.Python builds do not conflict and
the archives are not downloaded five times.

## CARLA source patches

`fetch-source.sh` applies three narrowly scoped patches:

- preserves both zlib include directories so libpng can find the generated
  `zconf.h` header;
- reads the distribution name, wheel release, description, Python range, and
  homepage from `distribution.json`, while keeping the compiled extension name
  `carla` required by `BOOST_PYTHON_MODULE(carla)`;
- tells the upstream PEP 517 target to use the prepared, pinned Python build
  environment instead of creating an unpinned isolated environment.

CARLA's own `0.10.0` CMake project version is not replaced by the wheel release
`0.0.1`; it continues to generate the correct client protocol version.
