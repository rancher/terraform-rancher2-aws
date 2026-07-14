# Plan Log

## TestSuite
- **Date:** Pending
- **Purpose:** Update the testsuite to be a single multi-package module in the `./test` directory. Update Go to the latest version and update all dependencies to their latest version. Provide a CI workflow to maintain this in the future.

## WorkflowStandards
- **Date:** 2026 August
- **Purpose:** Update all workflows to have a standard step structure, extract all scripts so they can be linted, use commit hashes for action versioning, and implement least privilege security principle.

## ContextLimitEnforcementHook
- **Date:** 2026 August
- **Purpose:** Implement a generic CLI hook in `.agent/hooks/` to automatically monitor and enforce context limits (e.g., 200,000 tokens) for agents like Gemini and Claude, preventing them from exceeding maximum token sizes and degrading performance.

## ScaffoldAgenticEnvironment
- **Date:** 2026 July
- **Purpose:** Provide a reproducible blueprint for scaffolding a unified, cross-platform AI agentic environment in any new or existing repository.

## ContainerizeCI
- **Date:** 2026 July
- **Purpose:** Update all GitHub workflows to use the `ghcr.io/rancher/ci-image/nix:20260603-18` container which comes with Nix pre-installed, and remove redundant steps that install Nix manually.
