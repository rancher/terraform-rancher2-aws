# Plan: Update GitHub Workflows to Use `ci-image` Container

**Executed Date:** July 7, 2026
**Purpose:** Update all GitHub workflows to use the `ghcr.io/rancher/ci-image/nix:20260603-18` container which comes with Nix pre-installed, and remove redundant steps that install Nix manually.

## Goals
1. Add the `container:` block to all `ubuntu-latest` jobs across workflows.
2. Remove the `install-nix` step from any jobs that previously needed it.
3. Remove global `env` variables related to the Nix installation.
4. Update the hardcoded `shell:` paths that point to `/home/runner/.nix-profile/bin/nix` as Nix is now installed in the container environment.

## Modifications

### 1. `.github/workflows/validate.yaml`
- **Add Container:** Update all jobs (`terraform`, `actionlint`, `shellcheck`, `validate-commit-message`, `gitleaks`, `test-compile-check`, `lint-tests`) to include the container block.
- **Remove Steps:** Remove the `install-nix` step from all jobs.
- **Remove Env Vars:** Remove `NIX_INSTALL_SHA` and `NIX_INSTALL_VERSION` from the global `env` block.
- **Update Shell Path:** Change the `shell:` configuration to use `nix` directly rather than the absolute path `/home/runner/.nix-profile/bin/nix`.

### 2. `.github/workflows/release.yaml`
- **Add Container:** Update jobs (`release`, `test`, `cleanup`, `report`) to include the container block.
- **Remove Steps:** Remove the `install-nix` steps from the `test` and `cleanup` jobs.
- **Remove Env Vars:** Remove `NIX_INSTALL_SHA` and `NIX_INSTALL_VERSION` from the global `env` block.
- **Update Shell Path:** Change the `shell:` configuration to use `nix` directly rather than the absolute path `/home/runner/.nix-profile/bin/nix`.

### 3. `.github/workflows/fossa.yml`
- **Add Container:** Update the `fossa-scanning` job to use the new container image. (Note: this job does not currently install Nix, but we'll update it to keep all runners consistent on the new image as requested).

### 4. Code Snippet to Add
Under each job that currently runs on `ubuntu-latest`:
```yaml
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/rancher/ci-image/nix:20260603-18
```

## Steps for Execution
1. Iteratively update each YAML file in `.github/workflows/` with the specified modifications.
2. Validate that the updated files adhere to the DevSecOps CI/CD reviewer standards defined in `.agent/rules/workflows.instructions.md`.
3. Mark this plan's Executed Date once the updates have been merged.
