---
applyTo: '**/*.{js,mjs}'
---

# JavaScript & Node.js Coding Standards (Reference Dictionary)

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured conceptual reference of **JavaScript & Node.js Coding Standards (Reference Dictionary)** within this repository. It establishes the clinical parameters, design rules, and operational constraints for this system area, ensuring standard-compliant environment initialization and developer safety.

This document is a dry, structured reference index of JavaScript syntax, security, and integration rules for local tooling, agent scripts, enforcer hooks, and GHA workflows.

---

## 1. Syntax, Formatting & Linter Compliance

- **Rule: Banned Empty Catch Blocks (Never Swallow Errors)**
  - **Constraint:** Absolutely no empty `catch` blocks or discarded exceptions may exist in any JavaScript file. Exceptions must be explicitly logged (via `console.error`, `core.error`, or standard logger) or handled.
- **Rule: GHA Export Definition (GHA Specific)**
  - **Constraint:** Every script run by `actions/github-script` MUST export an asynchronous default function receiving the action context object (e.g. `export default async ({ github, context, core, process }) => { ... }`).
  - **Exception:** `backport-issues.js` which is imported as a separate trigger.
- **Rule: Banned GHA Package Imports (GHA Specific)**
  - **Constraint:** Never manually import or require `@actions/github` or `@actions/core` inside GitHub Script runner files. Rely strictly on the injected function parameters.

## 2. Robust Logic, State & Error Resilience

- **Rule: Fail-Safe JSON Parsing (State Management)**
  - **Constraint:** All JSON file reads and parsing routines (such as loading `phase-state.json`) must be wrapped in `try-catch` blocks, providing a fallback to a fresh default state if corrupt or malformed JSON is encountered.
- **Rule: Mandatory Octokit Pagination (GHA Specific)**
  - **Constraint:** All GHA REST API calls that return arrays (like listing PR comments or repositories) MUST use the `github.paginate` wrapper to guarantee exhaustive collection of paginated results.
- **Rule: Preferred REST over GraphQL (GHA Specific)**
  - **Constraint:** Prefer `github.rest.[endpoint]` for standard operations. If GraphQL is structurally required, ensure the query is parameterized.
- **Rule: Mandatory Async Await (GHA Specific)**
  - **Constraint:** All asynchronous API calls (e.g., `github.rest.*` or `core.*`) must be explicitly prefixed with `await` to prevent race conditions.

## 3. Concurrency, Safety & Execution (Vulnerability Prevention)

- **Rule: Safe Subprocess Execution (Command Injection Prevention) (CRITICAL)**
  - **Constraint:** All Git, GitHub CLI (`gh`), and system CLI executions inside local scripts and hooks MUST use `execFileSync` (or `execFile`) with positional argv arrays. Never use string formatting or template interpolation to execute commands, as this creates shell-injection risks.
- **Rule: Banned Automatic Destructive Git Operations (CRITICAL)**
  - **Constraint:** Automation scripts and hooks are strictly forbidden from running destructive git commands (`git reset --hard` or `git clean -fd`) automatically without explicit user-approved confirmation.
- **Rule: Correct Private Key Signing (SSH Sign)**
  - **Constraint:** `ssh-keygen -Y sign` invocations in signing hooks, unit tests, and shell wrappers must always be passed the private key file path, never the public `.pub` key file path.
- **Rule: Sanitized GHA Webhook Payloads (GHA Specific)**
  - **Constraint:** Treat all inputs from `context.payload` (PR titles, issue bodies, authors) as untrusted, untethered strings. Sanitize them before running regex matches or logging them.
- **Rule: Graceful API Failures (GHA Specific)**
  - **Constraint:** Wrap all GHA API operations in `try-catch` blocks, calling `core.setFailed(error.message)` on failure to gracefully exit with a clear error annotation.

## 4. Automation Quality Gates, Testing & Architecture

- **Rule: Gate Artifact Tamper Protection**
  - **Constraint:** Enforcer hooks (such as file-write validators) must implement a strict denylist blocking edits, creation, or replacement of gating artifacts (e.g., `*-approval.json`, `*.sig`, `*.challenge`).
- **Rule: Immediate State Revocation on Non-Compliance**
  - **Constraint:** If a validation step detects empty, missing, corrupt, or non-compliant outputs, the script must actively unlink or delete (`unlink` or `rm`) the active phase approval file (e.g., `review-approval.json`) and delete associated state flags (e.g., `require-ask-user.flag`) to prevent stale approvals from persisting.
- **Rule: GHA UI-Native Logging (GHA Specific)**
  - **Constraint:** Avoid using raw `console.log()` inside GHA scripts. Use `core.info()`, `core.notice()`, `core.warning()`, or `core.error()` to ensure logs are natively parsed and annotated in the Actions runner UI.
- **Rule: Explicit Output Bindings (GHA Specific)**
  - **Constraint:** Set workflow step outputs explicitly using `core.setOutput('name', value)` rather than relying on the function's implicit return value.
