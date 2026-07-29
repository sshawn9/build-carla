# CARLA 0.9.15 Python wheels

This directory builds the CARLA 0.9.15 client wheels for CPython 3.10 through
3.14. The build runs in Ubuntu 20.04 so the resulting wheels can target
`manylinux_2_31_x86_64`.

The PyPI distribution name and release version are fixed in
`distribution.json`. With the current values, the output names follow this
pattern:

```text
carla_0_9_15-0.0.1-cp<ABI>-cp<ABI>-manylinux_2_31_x86_64.whl
```

The distribution is installed as `carla-0-9-15`; the Python import remains
`carla`, and the CARLA client version remains `0.9.15`.

## Build

Docker and an x86-64 Linux host are required. The original build entrypoint is:

```bash
./0.9.15/python-api/build.sh
```

The command has no options. Python versions and build paths are fixed in
`scripts/config.sh`. Wheels and build metadata are written to `dist/wheels/`;
persistent source, runtimes, downloads, and intermediates are kept under
`.work/`.

## Build flow

```text
build.sh
└── Ubuntu 20.04 container
    └── scripts/build-in-container.sh
        ├── config.sh                fixed versions and paths
        ├── install-dependencies.sh  system compiler and libraries
        ├── Astral uv installer      Python toolchain installer
        ├── prepare-python.sh        CPython runtimes and Python packages
        ├── fetch-source.sh          sparse CARLA checkout and active patches
        ├── build-wheels.sh          native dependencies and raw wheels
        ├── repair-wheels.sh         auditwheel repair and import tests
        └── write-metadata.sh        manifests, checksums, and license
```

Files under `scripts/` are internal build phases. `build.sh` invokes them in the
required order and restores ownership of generated files when the container
exits.

## Docker image flow

The Dockerfile-based flow is a separate entrypoint and does not change or call
the original `build.sh` flow:

```bash
./0.9.15/python-api/build-docker.sh
```

It builds `carla-python-api-builder:0.9.15`. The Dockerfile calls the existing
`scripts/build-in-container.sh`; the completed wheels and build state remain
inside the resulting image. It does not run a second container after
`docker build` finishes.

## Repository layout

| Path | Purpose |
| --- | --- |
| `build.sh` | Original Ubuntu 20.04 container build |
| `build-docker.sh` | Independent Dockerfile-based build |
| `Dockerfile` | Ubuntu 20.04 builder image definition |
| `.dockerignore` | Excludes persistent work and output from the image context |
| `scripts/` | Internal build orchestration and phases |
| `scripts/config.sh` | Fixed Python versions, paths, and build settings |
| `distribution.json` | PyPI distribution name, release version, and package metadata |
| `patches/` | One independently named patch per CARLA build change |
| `.work/` | Persistent ignored build state |
| `dist/wheels/` | Final ignored output |

## CARLA compatibility patches

`fetch-source.sh` defines one function for every patch. The calls in `main`
are the complete ordered list of enabled patches. They adapt CARLA's original
BuildTools chain for a client-only build without a full Unreal Engine tree:

- uses Ubuntu 20.04's Clang 10 and libc++;
- fixes the CARLA client version at `0.9.15`, independently of the PyPI
  distribution release in `distribution.json`;
- loads the PyPI distribution metadata from `distribution.json` before wheel
  construction;
- redirects archives whose original URLs moved;
- fetches new OSM2ODR checkouts as shallow sparse checkouts;
- supports the selected CPython versions, including Boost.Python fixes needed
  by Python 3.11 and later;
- reuses one Boost source archive across all selected Python versions, then
  removes it after the loop;
- builds patchelf 0.19.1, which correctly preserves ELF segment alignment;
- builds PROJ C sources as position-independent code.

Two client-only build optimizations are also defined but deliberately not
called:

- `apply_osm2odr_client_only_patch` removes both server build blocks from
  `BuildOSM2ODR.sh`, leaving the client library linked by the Python extension.
- `apply_skip_server_dependency_builds_patch` skips the libc++ rpclib and GTest
  builds, the server Xerces and PROJ builds, the server-only Eigen download, and
  server dependency copies in `Setup.sh`. It requires the OSM2ODR client-only
  patch.
