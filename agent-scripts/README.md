# Gated Agentic Workspace Controller & Hook Utilities

## Abstract

This directory contains a modular suite of GHA UI-native and shell-compliant utility scripts that orchestrate the Gated 4-Phase Lifecycle (Plan, Implement, Review, Commit) and enforce our strict **Gated 3-Gate Architecture**. These tools validate staging counts, ensure remote fast-forward ancestry, verify cryptographic plan/review signatures, and automate secure, Conventional GPG/SSH-signed commits.

For a detailed explanation of the three-tier hierarchy (Libraries, Tools, Scripts) used in this folder, please refer to the [Agent Scripts Architecture Reference Document](../docs/development/reference/AgentScriptsArchitecture.md).

---

## The Gated 3-Gate Architecture

Our development lifecycle enforces three rigorous cryptographic and programmatic gates to protect the repository's integrity and quality:

1. **Planning Gate (Gate 1) [User-facing]**: Triggered after drafting a proposed change checklist under `plans/`. The developer must cryptographically sign off on the plan (via GPG/Touch ID), writing the `plan-approval.json` signature to unlock the Implement Phase.
2. **Programmatic Review/Testing Gate (Gate 2) [Programmatic/Automated]**: Triggered during local test/linter verification. This gate programmatically runs our Map-Reduce Review pipeline via `code-review.js`. It delegates parallel file reviews to `@heads_down_coder` and architectural review to `@lead_architect`, consolidating results via `@data_scientist` and evaluating them via `@project_manager`. If no remediation tasks remain, it automatically signs the `review-approval.json` signature on disk.
3. **Commit Gate (Gate 3) [User-facing]**: Triggered when initiating final push and PR creation. The developer must cryptographically sign the unstaged Git diff (via GPG/Touch ID), writing `user-approval.json` to securely stage, commit, and push changes to GitHub.

---

## 1. Libraries (`agent-scripts/lib/`)

These foundational, highly-reusable, and stateless files provide low-level utility primitives and system integration boundaries:

- **`approval.js`**: Low-level cryptographic signature generation, validation, and key-management.
- **`ci.js`**: Low-level interfaces with Continuous Integration pipelines and remote log parsing.
- **`file.js`**: Safe path resolution and atomic filesystem reading, writing, and deletion.
- **`gemini.js`**: Spawns subagents with exponential backoff on rate limits.
- **`git.js`**: Performs status parsing, branch resolution, diff accumulation, and command execution.
- **`plan.js`**: Low-level validation rules and structural layout verification for planning documents.
- **`pr.js`**: Interacts with the GitHub CLI (`gh`) to view, update, comment, and resolve threads on Pull Requests.
- **`state.js`**: Locks, tracks, and transitions workspace phase states safely.
- **`test.js`**: Low-level execution of unit and linters runners and parsing log files.
- **`workspace.js`**: Dynamically resolves the active user home directory and temporary path for the session.

---

## 2. Tools (`agent-scripts/tools/`)

These executable command-line interfaces act as multi-call binary wrappers and the **exclusive entrypoint/façades** to their corresponding libraries:

- **`approval.js`**: CLI wrapper around low-level signature generation and validation routines.
- **`ci.js`**: CLI wrapper around CI log pulling and validation.
- **`file.js`**: CLI wrapper supporting safe read, write, delete, and execution actions.
- **`gemini.js`**: CLI wrapper around subagent rate-limit resilient execution.
- **`git.js`**: CLI wrapper supporting conventional commit and push checks, ancestry, and staging limits.
- **`plan.js`**: CLI wrapper to search, read, checksum, and validate plan file requirements.
- **`pr.js`**: CLI wrapper exposing detailed view, reply, and resolution commands on GitHub PRs.
- **`state.js`**: CLI wrapper to initialize, read, lock, and transition phase state flags.
- **`test.js`**: CLI wrapper executing pre-review, product, or agent-script tests and formatting reports.
- **`workspace.js`**: Façade exposing the target temporary workspace directory resolution.

---

## 3. Higher-Level Scripts (`agent-scripts/`)

These goal-oriented, cross-cutting automation scripts execute sequences of Level-2 tools to accomplish complex repository pipeline tasks:

- **`cleanup-data.js`**: Dynamically detects the active session ID via `logs.json` and purges older, stale temporary directories securely.
- **`code-review.js`**: Core parallelized Map-Reduce review orchestrator. Executes sandboxed, rate-limit resilient subagent audits.
- **`exercise-agents.js`**: Sequentially exercises requested Gemini models (pro, flash, lite) using isolated temporary sandboxes to manage quota reset times.
- **`exercise-cron.sh`**: Helper wrapper to schedule and execute the agent-exercising process automatically inside a Mac cron job.
- **`resolve-pr-reviews.js`**: Automates the parsing and resolution of GitHub PR review threads based on implemented fixes.
- **`run-in-nix.sh`**: Environment bootstrapper to securely run Javascript/Shell tasks in a hermetic, reproducible Nix environment.
- **`sync-boilerplate.js`**: Lightweight utility to compare and synchronize repository configuration and boilerplate files against a central template.
- **`update-action-versions.sh`**: Scans and upgrades outdated third-party GitHub Action dependencies within workflows.
- **`update-modules.sh`**: Scans and upgrades Go dependency modules to keep the provider dependencies up-to-date.
