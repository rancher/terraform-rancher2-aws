---
applyTo: "**/*.{sh,bash}"
---

# Shell Script PR Review Standards

As a strict CI/CD and automation reviewer, enforce these standards on all shell script changes. Flag violations with a concise explanation and provide the refactored script block.

## 1. Safety & Execution (Critical)
* **Context-Aware Shebangs:** Always declare the intended interpreter at the top of the file.
  * For controlled environments (CI/CD workflows, local Nix execution), prefer `#!/usr/bin/env bash` or `#!/bin/bash`.
  * For scripts running on target infrastructure (e.g., cloud-init, `remote-exec`), you MUST write POSIX-compliant scripts using `#!/bin/sh` to avoid failures on systems like Ubuntu that use `dash` as the default shell.
* **Fail Fast:** All scripts MUST fail fast. Use `set -euo pipefail` for Bash scripts. For POSIX `sh` scripts, use `set -eu` at a minimum (as `pipefail` is a bashism).

## 2. Syntax & Best Practices
* **Linting:** Enforce `shellcheck` best practices aggressively. Ensure reviewers check the script context (e.g., using `shellcheck -s sh` for POSIX scripts to flag accidental bashisms).
* **Conditionals:** 
  * In **Bash** scripts, prefer double brackets `[[ ]]` over single brackets `[ ]` to prevent word splitting and path expansion issues.
  * In **POSIX** scripts, you MUST use single brackets `[ ]` and quote variables aggressively.
* **Variable Expansion:** Always quote variable expansions (e.g., `"${VAR}"` instead of `$VAR`) unless word splitting or globbing is explicitly required and documented.
* **Command Substitution:** Always use `$(command)` instead of backticks `` `command` ``.

## 3. Naming Conventions & Structure
* **Variable Scoping:** Always use `local` for variables inside functions to prevent global scope leakage.
* **Naming:** Use `UPPER_CASE` for global/environment variables and `lower_case` for internal/local variables.
* **Modularity:** For scripts longer than 50 lines, organize logic into discrete functions (e.g., `cleanup() { ... }`) rather than a single monolithic block.
* **Main Execution:** If using functions, invoke the main logic at the very bottom of the script (e.g., `main "$@"`).

## Review Constraints
* Ignore formatting issues if the script is otherwise safe, but fix any syntax that would fail `shellcheck`.
* Provide the exact refactored Bash code block in your recommendation.
