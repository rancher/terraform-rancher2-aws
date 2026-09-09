---
applyTo: '**/*.{sh,bash}'
---

# Shell Script Coding Standards (Reference Dictionary)

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured conceptual reference of **Shell Script Coding Standards (Reference Dictionary)** within this repository. It establishes the clinical parameters, design rules, and operational constraints for this system area, ensuring standard-compliant environment initialization and developer safety.

This document is a dry, structured reference index of shell script (Bash and POSIX sh) syntax, safety, execution, and structure rules.

---

## 1. Safety & Execution (Critical)

- **Rule: Context-Aware Shebangs**
  - **Constraint:** Always declare the intended interpreter at the top of the file.
  - **Bash (Nix, CI, Local):** Use `#!/usr/bin/env bash` or `#!/bin/bash`.
  - **POSIX (Target/Cloud-init):** You MUST use `#!/bin/sh` to ensure compatibility with environments (such as Ubuntu) that use `dash` as the default.
- **Rule: Fail Fast Parameters**
  - **Constraint:** All scripts must terminate immediately upon error.
  - **Bash:** Use `set -euo pipefail`.
  - **POSIX sh:** Use `set -eu`. (Do not use `pipefail` as it is a bashism).
- **Rule: Safe Variable Expansion**
  - **Constraint:** Always wrap and quote variable expansions to prevent word splitting and glob expansion.
  - **Bad:** `rm -rf $DIR_PATH/*`
  - **Good:** `rm -rf "${DIR_PATH:?}"/*`

## 2. Syntax, Conditionals & Linters

- **Rule: Shellcheck Compliance**
  - **Constraint:** All shell scripts must pass `shellcheck` with zero findings.
  - **Tip:** For POSIX scripts, run `shellcheck -s sh` to explicitly prevent accidental bashisms.
- **Rule: Safe Conditionals**
  - **Constraint:** Apply the correct conditional bracket syntax based on the interpreter.
  - **Bash:** Prefer double brackets `[[ ]]` (prevents word splitting and path expansion issues).
  - **POSIX sh:** Must use single brackets `[ ]` and aggressively quote inside them.
  - **Bad (Bash):** `if [ $VAR = "value" ]; then`
  - **Good (Bash):** `if [[ "${VAR}" == "value" ]]; then`
- **Rule: Command Substitution Syntax**
  - **Constraint:** Always use `$(command)` for command substitution. Backticks are strictly banned.
  - **Bad:** `CURRENT_DIR=\`pwd\``
  - **Good:** `CURRENT_DIR="$(pwd)"`

## 3. Naming Conventions & Modularity

- **Rule: Local Variable Scoping**
  - **Constraint:** Always declare variables inside functions with the `local` keyword to prevent global state leakage.
  - **Exception:** Not available in standard POSIX `sh`.
- **Rule: Variable Naming Style**
  - **Constraint:** Use `UPPER_CASE` for global, configuration, or environment variables. Use `lower_case` (or snake_case) for internal, local, or helper variables.
- **Rule: Mandatory Modularity**
  - **Constraint:** Organize all script logic into cohesive, single-responsibility functions (e.g., `cleanup()`, `validate()`) rather than writing a single monolithic script block.
- **Rule: Help and Usage Standard**
  - **Constraint:** Every shell script must implement standard usage and help parsing. Parse `-h` and `--help` options, print a well-formatted instruction manual via a `show_help()` function, and exit cleanly with status `0`.
- **Rule: Mandatory Main Execution Entry**
  - **Constraint:** Every script must have a `main()` function at the very bottom of the script that orchestrates the execution flow. Invoke it explicitly as `main "$@"`.
  - **Good:**

    ```bash
    main() {
        parse_args "$@"
        run_process
    }
    main "$@"
    ```

## 4. Test Scripts, Makefiles & Cleanup

- **Rule: Independent Makefile Actions**
  - **Constraint:** The repository's `Makefile` must run outside the dev environment context, detect/warn if Nix is missing, and define these four actions:
    - `lint`: Runs the workflows-identical linter command.
    - `test`: Runs the `run_tests.sh` script without options.
    - `build`: Builds the global plugin cache and validates examples.
    - `cleanup`: Accept an `id` and executes `cleanup.sh` with that ID.
- **Rule: Automated Test Runner (`run_tests.sh`)**
  - **Constraint:** Acceptance tests must run through `run_tests.sh` supporting:
    - `--lint-only`: Executes linters only.
    - `--build-only`: Executes build only.
    - `--cleanup_id`: Restricts cleanup to a specific run ID.
    - `--slow-mode` / speed overrides.
    - Offline local plugin cache seeding to avoid rate limits.
- **Rule: Guaranteed Cleanup Execution**
  - **Constraint:** The cleanup sequence MUST execute within a bash `trap` (on `EXIT`, `ERR`, `INT`, etc.) inside `run_tests.sh` so that cleanup runs even if the runner crashes or is canceled.
- **Rule: Standard Tagged Cleanup (`cleanup.sh`)**
  - **Constraint:** Sourced as a standalone script. If no run ID is provided, it must find and destroy resources tagged with: `"Owner" = "terraform-ci@suse.com"`.
