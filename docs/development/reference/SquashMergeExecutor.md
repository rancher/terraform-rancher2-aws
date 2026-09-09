# Auto-Merging Component: Squash Merge & SemVer Safety Executor

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

The **Squash Merge & SemVer Safety Executor** component is the execution and regulatory enforcement engine of the automated merging pipeline. Implemented inside `merge-pr.js` and executed within the `merge-pr` job of `pr-executor.yml`, this subsystem uses the standalone Copilot CLI (`copilot`) to consolidate the PR's commit history into a high-quality Conventional Commit message. Crucially, it applies strict SemVer boundaries based on file scope to prevent automated release pipelines (`release-please`) from triggering incorrect semantic version increments.

---

## Technical Specification

### 1. Execution Trigger & Context

The squash merge execution is triggered directly after requirements verification passes and the dynamic `GITHUB_MERGE_TOKEN` is successfully retrieved from Vault. It executes `merge-pr.js` inside the secure Nix container environment.

If the merge execution encounters any errors, the orchestrator triggers `handle-merge-failure.js`. For fork-based PRs (where GitHub Actions token permissions often restrict direct automated merges), this failure handler gracefully posts a detailed explanatory comment and applies a `ready-to-merge` label to alert maintainers. For same-repository branch PRs, it logs the merge failure directly in the Actions runner logs for debugging.

---

### 2. Core Functional Mechanics

The executor carries out three major operational steps:

### A. Dynamic Conventional Commit Squash Generation

- **Mechanism**: The script compiles the entire list of commits in the PR (`listCommits`) and sends it to the standalone Copilot CLI (`copilot`) inside the Nix container environment.
- **Instruction Prompting**: Copilot is instructed to evaluate the commit list and craft a consolidated, high-quality, and syntactically correct Conventional Commit title and body description.
- **Retry & Validation Loop**: The script validates the generated title. If the generated message is invalid (e.g., syntactically incorrect or violates SemVer boundaries), the script feeds the error back to Copilot and attempts regeneration (up to 3 attempts).
- **Fallback**: If all AI attempts fail, the script falls back to a deterministic parsing of the initial commit message, appending a standard `fix:` prefix if the message does not possess a conventional type.

### B. Strict SemVer Enforcer Boundaries

To prevent the automated release system (`release-please`) from triggering accidental version increments, the executor enforces strict structural boundaries:

- **Product Scope**: Functional product code resides strictly within the `internal/` directory.
- **Product Changes (Inside `internal/`)**: The commit title is allowed to use `feat`, `refactor`, `fix`, or breaking `!` modifiers as necessary. These changes are allowed to trigger Minor or Major semver bumps on release-please.
- **Non-Product Changes (Outside `internal/`)**: If the modified files are strictly outside `internal/` (such as documentation, examples, workflows, or tests), the commit title is strictly barred from using `feat`, `refactor`, or `!` breaking-change indicators. This prevents release-please from triggering accidental version increments for non-product changes. The script automatically rewrites or downgrades invalid types to `chore` or `fix`.

### C. Secure GitHub CLI Auto-Merging

- **Auto-Merge Command**: The script executes the GitHub CLI command:
  `gh pr merge <number> --auto --squash --subject <title> --body <body>`
- **Native Queueing**: This native `--auto` flag instructs GitHub's backend to enable auto-merge, queuing the PR to merge automatically as soon as any remaining branch protection checks pass.
- **REST API Fallback**: If the CLI invocation fails or auto-merge is unsupported, the script catches the error and executes a direct squash-merge via GitHub's REST API (`pulls.merge`).

---

## Standing Implementation Decisions

### Nix Hermetic Tooling

- The Copilot CLI and GitHub CLI commands must execute within the Nix container shell environment (`.github/workflows/scripts/nix-run.sh`) to guarantee absolute environment reproducibility and eliminate runner-specific behavior.

### Preserving Commit Traceability

- The generated squash commit body must explicitly append the list of original commits (`Original Commits:`) under a markdown list. This maintains full historical traceability, ensuring that individual commit authors are permanently credited in the Git log after squashing.
