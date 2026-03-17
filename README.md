# build-tools

Utility GitHub Actions workflows for building Python wheels on platforms where
pre-built binaries are not available.

---

## `cryptography` — Windows ARM64 Wheel Builder

Builds the [`cryptography`](https://pypi.org/project/cryptography/) package as
a native Windows ARM64 `.whl` file using a `windows-11-arm` GitHub Actions
runner.

### Why this exists

`pip` / `poetry` cannot install `cryptography` on Windows ARM64 because no
pre-built wheel is published for that platform, and building from source locally
requires a working Rust + OpenSSL toolchain that is difficult to set up on
ARM64 Windows.

---

## Part A — Running the workflow

### Option 1: GitHub UI

1. Go to the **Actions** tab of this repo on GitHub.
2. Click **"Build cryptography wheel (Windows ARM64)"** in the left sidebar.
3. Click **"Run workflow"** (top-right of the workflow table).
4. Fill in the inputs:
   - **Python version** — must match the Python your project uses (e.g. `3.12`)
   - **cryptography version** — pin to a specific version (e.g. `44.0.2`) or
     leave blank for the latest release.
5. Click the green **"Run workflow"** button.
6. Wait ~10–15 minutes for the build to complete.

### Option 2: GitHub CLI

```bash
gh workflow run build-cryptography-arm64.yml \
  --repo L337-ai/build-tools \
  -f python_version=3.12 \
  -f cryptography_version=44.0.2
```

Leave out `-f cryptography_version=...` to build the latest version.

Watch progress:

```bash
gh run watch --repo L337-ai/build-tools
```

---

## Part B — Installing the wheel on your machine

### Step 1 — Download the artifact

```bash
gh run download \
  --repo L337-ai/build-tools \
  --name cryptography-cp3.12-win-arm64 \
  --dir C:/_code/wheels/
```

If you need to find the right run ID first:

```bash
gh run list --repo L337-ai/build-tools
```

### Step 2 — Install into your project

**With Poetry:**

```bash
cd C:/_code/tlc-auth-project
poetry run pip install C:/_code/wheels/cryptography-*.whl
```

**With plain pip:**

```bash
pip install C:/_code/wheels/cryptography-*.whl
```

### Step 3 — Prevent Poetry from overwriting it

If you run `poetry install` again, it may attempt to rebuild `cryptography`
from source and fail. Re-run the install command above after any `poetry install`
to restore the wheel:

```bash
poetry install
poetry run pip install C:/_code/wheels/cryptography-*.whl
```
