---
paths:
  - ".github/**"
  - "Makefile"
---

# CI and Makefile background

## One Makefile target per CI step

- `.github/workflows/check.yml` calls the Makefile targets directly, so
  local `make check` and CI run the same thing. Tools come from
  flake.lock's nixpkgs via `nix run --inputs-from .`, i.e. the same
  versions as `home.packages` / conform.nvim.
- `check.yml` runs on Linux: nothing builds the darwin system, it's only
  evaluated (`drvPath`), and eval is platform-independent.
- gitleaks also runs as a local pre-commit hook (`init.templateDir`), but
  that only covers clones made after it was set up, so CI scans the whole
  history (`fetch-depth: 0`).

## `terraform.yml` split

- Split out of `check.yml` because terraform is unfree, so cache.nixos.org
  has no build of it and every run compiles it from source (~5.5 min, most
  of the old `check.yml` runtime).
- It runs only when something that can change the result changes: the
  `.tf` files, `flake.lock` (terraform's version), the Makefile or the
  workflow itself. `make check` still runs it locally.

## `update-flake-lock.yml` dispatching the checks

- A PR opened with `GITHUB_TOKEN` only gets `pull_request` runs in an
  approval-required state, so `check.yml` wouldn't run on it unattended.
  `workflow_dispatch` always creates a run even from `GITHUB_TOKEN`, and
  that run is reported on the PR's head commit — hence the
  `gh workflow run` step and the `workflow_dispatch` trigger on
  `check.yml`/`terraform.yml`.

## Dependabot

- Only `github-actions`: flake inputs are updated by
  `update-flake-lock.yml`, and the pinned images in `services/` go through
  `.claude/skills/upgrade-services` (dashboard checks) instead of blind
  bumps.
