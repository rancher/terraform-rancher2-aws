# Temporary Execution Plan: Containerize CI

## Goals
1. Add the `container:` block to all `ubuntu-latest` jobs across workflows.
2. Remove the `install-nix` step from any jobs that previously needed it.
3. Remove global `env` variables related to the Nix installation.
4. Update the hardcoded `shell:` paths that point to `/home/runner/.nix-profile/bin/nix` to just `nix`.
5. Ensure compliance with `.agent/rules/workflows.instructions.md` (e.g. adding `timeout-minutes` to jobs).

## Progress
- [x] Create this temporary plan
- [x] Update `.github/workflows/fossa.yml`
- [x] Update `.github/workflows/validate.yaml`
- [x] Update `.github/workflows/release.yaml`
- [x] Update `.agent/plans/ContainerizeCI.md` with Executed Date
