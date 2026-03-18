# ARM64 Windows — `cryptography` Package Resolution

**Prepared for:** Project Architect
**Date:** 2026-03-17
**Scope:** All Python services in the L337-ai org running on Windows ARM64

---

## The Problem

The [`cryptography`](https://pypi.org/project/cryptography/) package is a
required dependency (directly or transitively via `tlc-auth`) across all
L337-ai Python services. On Windows ARM64, `pip`/`poetry` cannot install it
because:

1. **PyPI has no pre-built `win_arm64` binary wheel.** The cryptography
   maintainers do not publish ARM64 Windows builds.

2. **Building from source also fails.** `cryptography` requires Rust
   (`openssl-sys` crate) and a native ARM64 OpenSSL. Getting that toolchain
   working on Windows ARM64 is complex and was previously attempted and
   abandoned.

3. **The Python environment was x64, not ARM64.** Development machines were
   running an x64 (AMD64) Python interpreter under emulation on ARM64 hardware.
   Even if a wheel had existed, it would have been the wrong architecture.

The previous workaround was a comment in `agent-coder-api`'s `pyproject.toml`:
*"use `poetry lock` only on ARM64; actual installation happens in Docker
(linux/amd64)."* This meant developers on ARM64 Windows could not run or test
services locally.

---

## The Root Cause

Two compounding issues:

| Issue | Detail |
|-------|--------|
| Wrong Python architecture | Poetry environments were created against `Python313` (AMD64/x64), not the native ARM64 Python also present on the machine |
| No ARM64 wheel on PyPI | `cryptography` simply has no `win_arm64` distribution; Poetry cannot install it and source builds fail |

---

## The Fix

### 1. Switch to Native ARM64 Python

An ARM64 Python 3.11 build was already installed at:
```
C:\Users\bri\AppData\Local\Programs\Python\Python311-arm64\python.exe
```

Each affected repo's Poetry environment is switched to this interpreter:
```powershell
poetry env use "C:\Users\bri\AppData\Local\Programs\Python\Python311-arm64\python.exe"
```

This is reversible at any time:
```powershell
poetry env use "C:\Users\bri\AppData\Local\Programs\Python\Python313\python.exe"
```

Both environments remain on disk; switching does not delete anything.

### 2. Build the ARM64 Wheel on GitHub Actions

A GitHub Actions workflow at `.github/workflows/build-cryptography-arm64.yml`
in this repo:

- Runs on a `windows-11-arm` runner (native ARM64)
- Installs OpenSSL for ARM64 via `vcpkg`
- Builds a `cryptography` wheel from source using the native Rust + OpenSSL
  toolchain
- Uploads the resulting `.whl` as a downloadable artifact

The workflow is manually triggered and accepts `python_version` and
`cryptography_version` as inputs. The built wheel is:
```
cryptography-46.0.5-cp311-abi3-win_arm64.whl
```

The `abi3` tag means this wheel is compatible with Python 3.11 and all future
versions — it will not need to be rebuilt for Python 3.12, 3.13, etc.

### 3. Host the Wheel as a Private PyPI Index

To make the wheel resolvable by Poetry without hardcoding local file paths, a
**PEP 503 simple package index** is hosted on GitHub Pages from this repo:

```
https://l337-ai.github.io/build-tools/simple/
```

Structure:
```
docs/
  simple/
    index.html                      ← root index listing packages
    cryptography/
      index.html                    ← links to wheel with sha256 hash
  packages/
    cryptography-46.0.5-cp311-abi3-win_arm64.whl
```

The `build-tools` repo is public (it contains only build tooling, no
proprietary code) to allow GitHub Pages to serve the index without
authentication.

### 4. Configure Poetry to Use the Index

In each affected service's `pyproject.toml`, two changes are made:

```toml
# Declare cryptography explicitly, pointing to our index.
# Required even when it's a transitive dep — Poetry's "explicit" source
# priority only applies to packages that declare it directly.
cryptography = {version = ">=46.0.0", source = "l337-arm64-wheels"}

# Add the index as an explicit source (only used for packages that declare it).
[[tool.poetry.source]]
name = "l337-arm64-wheels"
url  = "https://l337-ai.github.io/build-tools/simple/"
priority = "explicit"
```

The `explicit` priority is intentional:
- Poetry uses this source **only** for `cryptography`
- All other packages continue to resolve from PyPI as normal
- On non-ARM64 environments (Docker, CI), this source is still queried but only
  serves the ARM64 wheel — Poetry will ignore it and use the appropriate PyPI
  wheel for the host platform instead

---

## Repos Updated

| Repo | Branch | Change |
|------|--------|--------|
| `L337-ai/build-tools` | `master` | New repo — workflow + GitHub Pages index |
| `L337-ai/tlc-auth` | `tag-code-mvp` | Added source + explicit cryptography dep |
| `L337-ai/agent-coder-api` | `tag-code-mvp` | Added source + explicit cryptography dep |

Remaining repos that depend on `tlc-auth` (and therefore `cryptography`)
will need the same two-line addition to their `pyproject.toml`. The pattern
is identical in each case.

---

## Adding a New Repo

For any repo that directly or transitively depends on `cryptography`:

```powershell
# 1. Switch to ARM64 Python (one-time per machine)
poetry env use "C:\Users\bri\AppData\Local\Programs\Python\Python311-arm64\python.exe"
```

```toml
# 2. Add to pyproject.toml
cryptography = {version = ">=46.0.0", source = "l337-arm64-wheels"}

[[tool.poetry.source]]
name = "l337-arm64-wheels"
url  = "https://l337-ai.github.io/build-tools/simple/"
priority = "explicit"
```

```powershell
# 3. Regenerate lock file and install
poetry lock --no-cache --regenerate
poetry install --no-cache
```

---

## Rebuilding the Wheel (Future Versions)

When `cryptography` releases a new version:

1. Trigger the workflow in this repo with the new version number
2. Download the artifact:
   ```powershell
   gh run download --repo L337-ai/build-tools --name cryptography-cp3.11-win-arm64 --dir C:\_code\wheels\cp311\
   ```
3. Publish to the GitHub Pages index:
   ```powershell
   .\build-tools\publish-wheel.ps1 -WheelPath "C:\_code\wheels\cp311\cryptography-X.Y.Z-cp311-abi3-win_arm64.whl"
   ```
4. Run in each affected repo:
   ```powershell
   poetry lock --no-cache --regenerate
   poetry install --no-cache
   ```

---

## What Is Not Changed

- Docker builds are unaffected — they run on `linux/amd64` and install
  `cryptography` directly from PyPI as normal
- CI pipelines are unaffected for the same reason
- Non-ARM64 developer machines are unaffected — Poetry will query the
  `l337-arm64-wheels` index, find no compatible wheel for their platform, and
  fall back to PyPI transparently
