# Portable Development Environment (.dev)

This directory contains the consolidated, hermetic development and CI environment definition for repositories in the Rancher namespace.

## Overview

The `.dev` directory groups all environment configuration files into a single portable directory that can be copied into any repository. It isolates workstation dependencies using the exact container image executed by GitHub Actions CI, while leveraging Nix flakes for reproducible toolchains.

## File Structure

| File               | Purpose                                                                                                                       |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `flake.nix`        | Declarative Nix flake partitioned into `ci` and `default` development shells.                                                 |
| `flake.lock`       | Cryptographically pinned dependency graph for all Nix packages.                                                               |
| `aliases.sh`       | Standard development workflow aliases (`gs`, `gd`, `tf`, `k`, `sc`).                                                          |
| `functions.sh`     | Shell utilities, dynamic prompt coloring, terminal sizing, and conventional commit helpers (`git_message`).                   |
| `variables.sh`     | Core environment variables (`TF_IN_AUTOMATION=1`, dynamic `PS1`, `GEMINI_SYSTEM_MD`).                                         |
| `rc.sh`            | Unified shell initialization script that sources variables, functions, aliases, and optional non-blocking personal overrides. |
| `container-run.sh` | Launches the containerized environment matching CI (`ghcr.io/rancher/ci-image/nix:20260603-18`).                              |
| `envrc.sh`         | Entrypoint for direnv integration, shell sourcing, and container delegation.                                                  |

## Architectural Principles

### 1. Partitioned Nix Flake Shells

Nix packages are split into distinct shell environments:

- **`devShells.ci`**: Pure CI toolchain containing compilers, linters, test runners, formatters, and CI automation tooling (Go, Terraform, gotestsum, actionlint, cspell, eslint, golangci-lint, shellcheck, shfmt, prettier, gitleaks, trivy, github-copilot-cli).
- **`devShells.default`**: Complete CI toolchain plus interactive developer tooling (`gemini-cli`, Claude Code, Node environment initialization, and Darwin-specific utilities).

### 2. Container-First Workstation Isolation

To prevent configuration drift between local workstations and CI, `container-run.sh` executes within `ghcr.io/rancher/ci-image/nix:20260603-18`:

- Mounts only the repository root into `/workspace`.
- Does not mount the host `$HOME` directory to prevent state leakage.
- Forwards necessary authentication tokens (`GITHUB_TOKEN`, `GH_TOKEN`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`).
- Forwards the host SSH authentication socket (`SSH_AUTH_SOCK`) when available.

### 3. Thin `.envrc` Interface

The repository root `.envrc` delegates directly to `.dev/envrc.sh`:

- When invoked under direnv on a workstation, it sources `.dev/rc.sh` and activates `use flake .dev#default`.
- When sourced interactively (`source .envrc`), it checks if Docker is running and launches the container; if Docker is stopped, it gracefully falls back to native `nix develop .dev#default`.
- When executed directly (`./.dev/envrc.sh`), it launches the isolated container via `container-run.sh`.

## Workstation Usage

### Option A: Shell Sourcing or Direnv (Recommended)

Set your repository root `.envrc` to:

```bash
#!/usr/bin/env bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DEV_DIR="${REPO_ROOT}/.dev"

if [[ -f "${DEV_DIR}/envrc.sh" ]]; then
  # shellcheck source=/dev/null
  source "${DEV_DIR}/envrc.sh" "$@"
fi
```

If using an alias such as `alias d='source .envrc'`, running `d` in your shell will initialize the environment. If using direnv, run `direnv allow`.

### Option B: Isolated Container

Launch an interactive shell inside the CI container:

```bash
./.dev/container-run.sh
```

Run a specific command inside the isolated container:

```bash
./.dev/container-run.sh make test
./.dev/container-run.sh make lint
```

### Option C: Native Nix Shell

If running natively on a POSIX workstation with Nix installed:

```bash
nix develop .dev#default
```

For the pure CI toolchain:

```bash
nix develop .dev#ci
```

## Migration Guide for Other Repositories

To migrate another repository in the Rancher namespace to the portable `.dev` structure:

1. Copy the entire `.dev/` directory into the target repository root. Ensure all shell scripts retain executable permissions (`chmod 0755 .dev/*.sh`).

2. Replace the target repository root `.envrc` with the thin delegation interface:

   ```bash
   #!/usr/bin/env bash
   REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
   DEV_DIR="${REPO_ROOT}/.dev"

   if [[ -f "${DEV_DIR}/envrc.sh" ]]; then
     # shellcheck source=/dev/null
     source "${DEV_DIR}/envrc.sh" "$@"
   fi
   ```

3. Update `.github/workflows/scripts/nix-run.sh` in the target repository to target `.dev#ci` when present:

   ```bash
   local flake_target="."
   if [[ -d "${PWD}/.dev" && -f "${PWD}/.dev/flake.nix" ]]; then
     flake_target="${PWD}/.dev#ci"
   fi

   sudo -E -u suse /home/suse/.nix-profile/bin/nix develop "${flake_target}" \
     --extra-experimental-features nix-command \
     --extra-experimental-features flakes \
     --command bash -e "${SCRIPT_FILE}" "$PWD" "$@"
   ```

4. Remove legacy sprawled files from the repository root:
   - `.aliases`
   - `.functions`
   - `.variables`
   - `.rcs`
   - Root `flake.nix` and `flake.lock`

5. If the target repository uses `.boilerplate-sync.json`, update the flake entry:

   ```json
   { "local": ".dev/flake.nix", "remote": ".dev/flake.nix" }
   ```

6. Update any internal test or cron scripts in the target repository that sourced `.functions` or `.variables` directly to locate `.dev/functions.sh` and `.dev/variables.sh`:

   ```bash
   if [[ -f ".dev/variables.sh" ]]; then
     source .dev/variables.sh
   elif [[ -f ".variables" ]]; then
     source .variables
   fi
   ```
