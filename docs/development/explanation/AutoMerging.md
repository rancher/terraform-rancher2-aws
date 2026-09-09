# Auto-Merging & Verification Infrastructure (Conceptual Explanation)

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured reflective conceptual explanation of **Auto-Merging & Verification Infrastructure (Conceptual Explanation)** within this repository. It establishes the clinical parameters, design rules, and operational constraints for this system area, ensuring standard-compliant environment initialization and developer safety.

This document provides a conceptual overview of the architecture, safety checks, and orchestrations governing our repository-wide, event-driven automated merging infrastructure.

---

## Purpose

To maintain high development velocity and absolute codebase stability, this repository employs a secure, zero-trust automated verification and merging pipeline. By offloading mechanical checks (such as CI status validation, cryptographic commit signatures, and trusted human/AI peer review approvals) to automated system hooks, we eliminate manual integration friction. Simultaneously, our pipeline ensures that every single commit entering our default branch complies with strict regulatory standards.

---

## 📂 Files Involved

To adopt or transplant this automated merging infrastructure, the following files under `.github/` are involved:

- **Workflow Orchestrator:**
  - `.github/workflows/pr-executor.yml`
- **Execution & Verification Scripts:**
  - `.github/workflows/scripts/get-target-pr.js` (Target PR resolution)
  - `.github/workflows/scripts/verify-pr-requirements.mjs` (Core quality gate and requirements check)
  - `.github/workflows/scripts/merge-pr.js` (AI message generation and squash-merge execution)
  - `.github/workflows/scripts/handle-verification-failure.js` (Verification failure reporting)
  - `.github/workflows/scripts/handle-merge-failure.js` (Merge failure reporting)
- **Unit & Integration Tests:**
  - `.github/workflows/scripts/tests/get-target-pr.test.js`
  - `.github/workflows/scripts/tests/verify-pr-requirements.test.js`

---

## 🧭 Modular Architectural Blueprints Map

The auto-merging infrastructure is organized into four detailed component specifications focusing on script integration, verification logic, authentication, and execution boundaries:

- **Pull Request Triggers & Target Resolution:** Details the `pr-executor.yml` workflow triggers, asynchronous `workflow_run` event contexts, automated `get-target-pr.js` target resolution fallback loops, and `release-please` branch exemption safety gates.
- **Pull Request Requirements Verification:** Details programmatic Quality Gate requirements evaluated by `verify-pr-requirements.mjs`, including CI status check completion, cryptographic GPG commit signature validation, trusted Human approval rules, AI review sign-offs, and Dependabot automated exemptions.
- **Vault Token Retrieval & Secret Management:** Details organization-level OIDC JWT trust relations and the usage of `rancher-eio/read-vault-secrets` to safely retrieve dynamic write-privileged `GITHUB_MERGE_TOKEN` secrets without PAT configuration.
- **Squash Merge & SemVer Safety Executor:** Details dynamic squash conventional commit message generation via Copilot CLI inside Nix, strict directory-based SemVer safety boundaries (preventing accidental bumps for non-product modifications), and native `gh pr merge --auto` CLI execution.
  Refactored code: N/A (Explanation is conceptual)
