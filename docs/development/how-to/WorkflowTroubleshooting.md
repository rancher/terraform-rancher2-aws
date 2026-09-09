# How to Troubleshoot CI/CD Workflows

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

This guide provides sequential, goal-oriented procedures for investigating, retrieving logs from, and resolving broken GitHub Actions CI/CD pipelines within our Gated 4-Phase Lifecycle.

---

## Abstract

When CI/CD or release pipelines fail, developers and autonomous agents must follow a structured troubleshooting process mapped to our Gated 4-Phase Lifecycle. This ensures that log retrieval, configuration auditing, planning, implementation, and verification remain safe, secure, and compliant.

---

## Phase 1: Plan (Triage, Audit, and Strategy)

During the Plan Phase, perform log retrieval and audits to diagnose the failure and secure Planning Gate (Gate 1) approval.

### Step 1: Retrieve and Analyze Logs

1. Identify failed runs by querying the repository:

   ```bash
   agent-scripts/pull-ci-logs.sh --list-failed
   ```

2. List individual job failures for the specific run ID (e.g., `123456789`):

   ```bash
   agent-scripts/pull-ci-logs.sh --list-jobs 123456789
   ```

3. Download the specific job logs (e.g., `987654321`) to isolate the failure:

   ```bash
   agent-scripts/pull-ci-logs.sh --job 987654321
   ```

### Step 2: Perform Script and Configuration Audits

1. Audit workflow files (`.github/workflows/*.{yml,yaml}`) and referenced scripts.
2. Check for missing safety flags (such as `set -euo pipefail`) or unsanitized credentials.
3. Formulate a robust fix that conforms to our standards, avoiding quick hacks that suppress warnings.

### Step 3: Document the Plan

1. Record your diagnostics and step-by-step resolution plan under `plans/`.
2. Obtain cryptographic Planning Gate (Gate 1) approval before modifying any files.

---

## Phase 2: Implement (Surgical Fixes)

During the Implement Phase, apply the designed script or configuration adjustments.

### Step 1: Apply Surgical Edits

1. Apply targeted corrections (such as path adjustments, variable sanitization, or argument parsing) strictly off your approved checklist.
2. Avoid making unrelated changes or refactoring outside the diagnosed area.

---

## Phase 3: Review (Local Dry-Run and Validation)

During the Review Phase, perform rigorous static and execution-path validation to obtain Programmatic Review/Testing Gate (Gate 2) approval.

### Step 1: Static Code Quality Checks

1. Run local linters on modified shell scripts:

   ```bash
   shellcheck agent-scripts/<script_name>.sh
   ```

2. Run local workflow validations if YAML files were modified:

   ```bash
   actionlint .github/workflows/<workflow_name>.yml
   ```

### Step 2: Run Local Dry-Runs

1. Execute the modified scripts locally with dry-run or mock flags to confirm the corrected execution paths before committing.
2. Verify that `review-approval.json` is generated upon a successful validation run.

---

## Phase 4: Commit (Finalization and Secure Push)

During the Commit Phase, finalize the changes, obtain Commit Gate (Gate 3) approval, and push.

### Step 1: Secure Commit and Push

1. Present the unstaged diff and verify exactly 0 quality gate warnings.
2. Run the secure commit hook to obtain GPG/Touch ID commit approval, commit, and push the active branch.

### Step 2: Log Triage Summary

1. Document a concise technical summary detailing the root cause, how the fix addresses it, and the quality gates used to verify correctness.
