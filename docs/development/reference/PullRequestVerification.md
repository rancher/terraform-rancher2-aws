# Auto-Merging Component: Pull Request Requirements Verification

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

The **Pull Request Requirements Verification** component is the central quality and security gate of the automated merging pipeline. Implemented inside `verify-pr-requirements.mjs` and executed within the `verify-pr` job of `pr-executor.yml`, this subsystem conducts comprehensive programmatic checks on CI status completion, commit cryptographic integrity, human reviews, and AI reviewer sign-offs before declaring a pull request eligible for automated merging.

---

## Technical Specification

### 1. Verification Trigger & Execution Context

The verification subsystem is triggered immediately after `get-target-pr.js` successfully resolves the target Pull Request number. It runs as a non-interactive read-only evaluation script under `verify-pr-requirements.mjs` using the standard repository action runner token.

If any check fails, the orchestrator triggers `handle-verification-failure.js`, which leaves or updates a detailed Markdown warning comment directly in the PR conversation thread summarizing the failed rules.

---

### 2. Core Gate Verification Rules

The subsystem evaluates the target PR against its core quality rules:

### A. CI Check Runs Verification

- **Rule**: All relevant CI checks (tests, linters, compiles) associated with the head commit SHA (`pr.head.sha`) must have completed successfully (`success` or `skipped`).
- **Deadlock Prevention**: The script dynamically filters out trigger, executor, and verification runs (e.g., "Verify PR Requirements", "PR Executor", "Trigger Executor on Event") from its evaluation pool. This ensures that the requirements check does not wait for itself to finish, avoiding pipeline deadlocks.
- **Failures**: If any check is in progress, the script marks the status as `ci_pending=true`. If any relevant check failed, it lists the failed checks explicitly in the final warnings.

### B. Cryptographic Commit Signatures

- **Rule**: Every single commit present in the Pull Request must be cryptographically signed (GPG/SSH signed) and successfully verified by GitHub.
- **Verification Details**: Utilizes paginated calls to `listCommits` and evaluates the `commit.verification.verified` field. Any unsigned or unverified commits will cause immediate failure, ensuring that all code additions are fully traceable to verified developers.

### C. Trusted Human Approval

- **Rule**: The PR must have at least one approved review from a trusted human contributor.
- **Trusted Status Evaluation**:
  - Analyzes the review's `author_association` (must be `OWNER`, `MEMBER`, or `COLLABORATOR`).
  - Calls `getCollaboratorPermissionLevel` via the GitHub API to dynamically verify that the reviewer possesses write-level permissions (`admin`, `write`, `maintain`, or `triage`).
  - Ignores reviews from any bots or service accounts.

### D. AI Reviewer Approval

- **Rule**: The PR must have at least one review with state `APPROVED` or `COMMENTED` from an authorized AI agent bot (whose username contains `copilot` or `agent`, and whose type is `Bot` or ends with `[bot]`).
- **Conversation Thread Fallback (Non-Dependabot Only)**: For non-Dependabot PRs, if no official AI review exists in the GitHub Reviews tab, the script searches the PR conversation comments history for a valid review pass comment containing the standard signature:
  `"and generated no new comments."`
  This issue-comment fallback path is strictly bypassed for Dependabot PRs.

### E. Dependabot Exemption

- **Rule**: Pull Requests submitted by the Dependabot service (`dependabot[bot]`) bypass the Human Approval requirement.
- **Logic**: While Dependabot PRs bypass the human approval rule, they are still strictly subjected to all other quality gates, including CI status completion, cryptographic commit signatures, unresolved review thread checks, and require an official AI bot review in state `APPROVED` or `COMMENTED` (bypassing the issue-comment fallback path). This ensures dependency updates are fully verified without weakening the overall quality gates.

---

## Standing Implementation Decisions

### Zero-Tolerance GPG Enforcements

- Cryptographic commit verification is absolute. There are zero exceptions or bypasses for commit signatures, ensuring the codebase is fully audit-compliant and protected against supply-chain vectors.

### Resilient API Retry Loop

- All external API calls in the script are wrapped in a retry handler (`withRetry`) that attempts each call up to three times with a progressive delay (default 2000ms) to withstand transient GitHub API rate-limiting or network issues.
