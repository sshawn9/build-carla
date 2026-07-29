# CARLA 0.9.16 Python wheels

This directory builds CARLA 0.9.16 client wheels for CPython 3.10 through
3.14. The build runs in Ubuntu 20.04 and repairs the wheels for
`manylinux_2_31_x86_64`.

`distribution.json` fixes the PyPI distribution metadata. With the current
values, output filenames follow this pattern:

```text
carla_0_9_16-0.0.1-cp<ABI>-cp<ABI>-manylinux_2_31_x86_64.whl
```

The distribution is installed as `carla-0-9-16`; the import remains `carla`,
and the CARLA client reports version `0.9.16`.

## Build

Docker and an x86-64 Linux host are required:

```bash
./0.9.16/python-api/build.sh
```

The command has no options. Fixed versions and paths live in
`scripts/config.sh`. Final wheels and metadata are written to `dist/wheels/`;
persistent source, runtimes, downloads, and intermediates remain under
`.work/`.

## Build flow

```text
build.sh
└── Ubuntu 20.04 container
    └── scripts/build-in-container.sh
        ├── install-dependencies.sh  system compiler and libraries
        ├── Astral uv installer      Python runtime installer
        ├── prepare-python.sh        CPython runtimes and build packages
        ├── fetch-source.sh          sparse CARLA checkout and patches
        ├── build-wheels.sh          client dependencies and raw wheels
        ├── repair-wheels.sh         auditwheel repair and import checks
        └── write-metadata.sh        manifests, checksums, and license
```

The independent Dockerfile flow builds an image containing the finished build:

```bash
./0.9.16/python-api/build-docker.sh
```

## Verify release artifacts

Run these commands from the repository root before uploading the wheels:

```bash
cd 0.9.16/python-api
(cd dist/wheels && sha256sum -c SHA256SUMS)
uvx twine check dist/wheels/*.whl
```

`SHA256SUMS` contains paths relative to `dist/wheels`, so its check must run
with that directory as the working directory.

## CARLA compatibility patches

`fetch-source.sh` has one function per patch; the calls in `main` are the
complete ordered list of enabled changes. They:

- use Ubuntu 20.04's Clang 10 instead of requiring an Unreal Engine toolchain;
- pin the reported CARLA client version to `0.9.16`;
- read the independent PyPI name and release version from `distribution.json`;
- use the prepared, pinned Python build environment without PEP 517 isolation;
- fix the moved libpng archive URL;
- reuse the verified Boost 1.84 source archive for all Python builds;
- build PROJ with position-independent C and C++ objects;
- upgrade patchelf to 0.19.1;
- skip server-only OSM2ODR and dependency builds while keeping the client
  OSM2ODR library used by the Python module;
- disable LibCarla unit tests.

CARLA 0.9.16 already uses the current `distro` API, a commit archive for the
OSM2ODR source, and the Boost.Python fixes that 0.9.15 needed as local patches;
those obsolete 0.9.15 patches are deliberately not carried forward.
