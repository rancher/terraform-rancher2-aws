---
applyTo: '.github/workflows/**/*.{yml,yaml}'
---

# GitHub Actions Workflow Coding Standards (Reference Dictionary)

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured conceptual reference of **GitHub Actions Workflow Coding Standards (Reference Dictionary)** within this repository. It establishes the clinical parameters, design rules, and operational constraints for this system area, ensuring standard-compliant environment initialization and developer safety.

This document is a dry, structured reference index of GitHub Actions workflow security, reliability, and orchestration rules.

---

## 1. Security & Hardening (Vulnerability Prevention)

- **Rule: Explicit Least-Privilege Permissions (CRITICAL)**
  - **Constraint:** All workflows must declare a global default `permissions: {}` (all scopes set to `none`) at the top level of the YAML file.
  - **Constraint:** Individual `jobs` must selectively enable only the exact scopes necessary for execution (e.g. `permissions: contents: read` for checking out code, `permissions: id-token: write` for AWS OIDC authentication).
- **Rule: Mandatory OIDC Federated Identity (CRITICAL)**
  - **Constraint:** Banned: Long-lived IAM user keys, service account credentials, or persistent API secrets inside GHA runner contexts.
  - **Constraint:** Always authenticate cloud and federated integrations (such as AWS, GCP, Azure, or Vault) securely using OpenID Connect (OIDC) tokens via native actions (e.g. `aws-actions/configure-aws-credentials`).
- **Rule: Pin Actions by 40-Character Commit SHA (CRITICAL)**
  - **Constraint:** Banned: Referencing mutable tag names or branches in `uses:` parameters (e.g., `uses: actions/checkout@v4`).
  - **Constraint:** All third-party actions (including first-party `actions/*`, `github/*`, `rancher/*`) MUST be pinned strictly to a full 40-character commit SHA hash.
  - **Constraint:** The version tag must be documented as a comment on the same line (e.g. `uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2`).
  - **Constraint:** The line _before_ the action block MUST contain a comment linking to the action's official GitHub releases page (e.g., `# https://github.com/actions/checkout/releases`).
- **Rule: Strict Namespace Allowlist (CRITICAL)**
  - **Constraint:** Banned: Executing third-party actions belonging to unapproved namespaces.
  - **Constraint:** Verify that used actions belong strictly to allowed namespaces documented in the standard security team index (such as `actions/*`, `aquasecurity/*`, `aws-actions/*`, `dependabot/*`, `fossas/*`, `golang/*`, `golangci/*`, `google-github-actions/*`, `goreleaser/*`, `hashicorp/*`, `rancher-eio/*`, `renovatebot/*`, and `updatecli/*`).
- **Rule: Banned Inline Context Interpolation (CRITICAL)**
  - **Constraint:** Banned: Direct interpolation of untrusted context fields (such as `github.event.pull_request.title`, `github.head_ref`, or GHA webhook payloads) into raw string templates inside `run:` or `github-script` blocks.
  - **Constraint:** Always pass untrusted contexts securely through dedicated environment variables (e.g., `env: PR_TITLE: ${{ github.event.pull_request.title }}` followed by `run: echo "PR Title is $PR_TITLE"`).
- **Rule: Banned `pull_request_target` Trigger (CRITICAL)**
  - **Constraint:** The `pull_request_target` trigger is strictly banned from all repository workflows. Use standard `pull_request` triggers instead.

## 2. Reliability & Performance

- **Rule: Mandatory Job-Level Timeouts**
  - **Constraint:** Every individual `job` MUST declare an explicit `timeout-minutes` value. Never omit this parameter or rely on GitHub's default 360-minute execution window.
- **Rule: Redundant Run Cancellation**
  - **Constraint:** Pull Request workflows must implement a `concurrency` block to automatically cancel previous, redundant pipeline runs for the same branch upon a new push (e.g. `group: ${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: true`), saving runner capacity.
- **Rule: Cached Runners Dependency**
  - **Constraint:** Speed up builds and test executions by implementing runner-level dependency caching via `actions/cache` or action-specific configuration toggles (such as `cache: go` on `actions/setup-go`).

## 3. Structure & Maintainability

- **Rule: Declarative Orchestration (Orchestrate, Don't Execute)**
  - **Constraint:** Workflows should act as clean orchestrators, not execution scripts. They should specify execution order, matrix setups, and permission boundaries, but delegate actual code execution to external actions or isolated scripts.
- **Rule: External Script Isolation**
  - **Constraint:** Avoid writing long inline Bash or JavaScript scripts directly inside workflow steps. Move all scripts longer than 5 lines into the dedicated `.github/workflows/scripts` directory.
- **Rule: External Script Validation**
  - **Constraint:** All external scripts placed in `.github/workflows/scripts` must be validated (such as running shell linter checks or formatting) inside the core `pull_request.yaml` workflow.
- **Rule: Descriptive Step Naming**
  - **Constraint:** Every single GHA `workflow`, `job`, and `step` MUST contain a descriptive `name` string describing its specific action, making annotations and pipeline runs easy to debug in the Actions execution UI.
- **Rule: Protected Environments**
  - **Constraint:** Any job utilizing production secrets or deploying to environments (such as Docker Hub, Terraform Registry, or Releases) must be gated behind a manual approval workflow using an `environment:` block configuration.
