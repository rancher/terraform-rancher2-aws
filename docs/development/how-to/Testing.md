# How to Run Linting, Formatting, and Code Quality Tests

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This guide provides sequential, goal-oriented instructions for verifying code quality, formatting files, running static analysis linters, and executing the test suites within our secure development environment.

---

## Step 1: Validate Your Hermetic Environment

Ensure you are operating inside the secure, hermetic Nix development shell. This guarantees that all required linters, formatters, and test runners (such as `golangci-lint`, `shellcheck`, `cspell`, and `go`) are locked to their precise repository versions.

---

## Step 2: Format All Codebase Assets

Before running linter checks or submitting code, you must format all files to satisfy the repository's formatting quality gates:

```bash
# 1. Format Go files:
make fmt

# 2. Format Shell files using shfmt:
shfmt -w agent-scripts/exercise-cron.sh

# 3. Format JavaScript, JSON, and Markdown files using Prettier:
npx prettier --write .
```

---

## Step 3: Run Static Analysis & Linters

Execute static analysis linter checks to catch potential security vulnerabilities, syntactic bugs, and style issues:

```bash
# 1. Run golangci-lint (gosec, errcheck, staticcheck):
make lint

# 2. Run Shellcheck on all Bash scripts:
shellcheck agent-scripts/exercise-cron.sh

# 3. Run ESLint on JavaScript hooks and scripts:
npx eslint .

# 4. Run CSpell to perform spellchecking:
cspell docs/development/reference/Go.md
```

---

## Step 4: Execute the Go Unit Test Suite

Run local unit tests to verify the core provider logic and utility packages:

```bash
# Run all Go unit and helper tests with coverage:
make test
```

---

## Step 5: Execute Terraform Acceptance Tests

Acceptance tests spin up real resources using Terraform to verify end-to-end compatibility. Always run acceptance tests before proposing a release:

```bash
# Execute all acceptance tests (seeds the plugin cache and executes test/):
make testacc
```

---

## Step 6: Generic Unified Testing & Linting Entrypoints

For unified and cross-repository automation (supporting Go, JavaScript, and Terraform-only modules), we provide generic bash entrypoints:

- `.github/workflows/scripts/test.sh`
- `.github/workflows/scripts/lint.sh`

These scripts are designed to be fully generic. They automatically detect the repository configuration and safely bypass language-specific verification steps:

- **`test.sh`**: Gracefully skips Go compilation, unit tests, and acceptance tests if no root `go.mod`, `test/` folder, or `Makefile` are detected.
- **`lint.sh`**: Skips Go-specific static analysis (`golangci-lint`, `go fmt`) when the root `go.mod` file is absent.
- **CI Workflows**: The workflows in `.github/workflows/pull_request.yaml` utilize these checks to dynamically bypass Go-specific CI verification steps on non-Go repositories (such as Terraform modules).
