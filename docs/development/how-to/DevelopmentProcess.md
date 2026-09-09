# Standard Gated Development Process

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

---

## Abstract

This component outlines the repository's standard, step-by-step developer and agent development process. It is structured around a **Gated 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and **3-Gate Architecture** (two of which are user-facing) to enforce strict planning, automated quality, and cryptographic biometric commits.

---

## The Three Authoritative Approval Gates

To maintain absolute system integrity and prevent unvetted code modifications, the development lifecycle is anchored around three sequential approval gates. The agent operates with full autonomous authorization between gates, but is strictly blocked from advancing phases or committing code until the respective gate is satisfied.

### **Gate 1: Planning Gate (User-Facing)**

- **Phase Transition**: Plan -> Implement.
- **Verification File**: `plan-approval.json` and `plan-approval.json.sig`.
- **Protocol**: Before any source or configuration files can be modified, the developer must review and cryptographically sign the dynamic implementation plan checklist using GPG/Touch ID.
- **Authorization**: Once Gate 1 is signed, the agent is granted full autonomous authorization to modify files, compile, and run tests.

### **Gate 2: Programmatic Review/Testing Gate (Gate 2)**

- **Phase Transition**: Implement -> Review.
- **Verification File**: `review-approval.json`.
- **Protocol**: This gate is programmatically validated by the enforcer hooks. It requires that:
  1. The automated unit and linter checks pass successfully, storing the tested diff_hash in `phase-state.json`.
  2. A proactive code review is executed by the isolated, sandboxed **Map-Reduce Review pipeline** coordinated by `agent-scripts/code-review.js`, which writes `review-approval.json` upon reporting a clean review.
- **Enforcement**: If any workspace files are modified after Gate 2 is signed, the enforcer hooks automatically delete the signatures, revoking approval and requiring re-testing and re-review.

### **Gate 3: Commit Gate (User-Facing)**

- **Phase Transition**: Review -> Commit.
- **Verification File**: `user-approval.json`.
- **Protocol**: The agent presents the active unstaged Git diff for visual IDE review. The developer explicitly approves the proposed Conventional Commit message via `ask_user` (format: `Commit Message: "docs: <description>"`).
- **Execution**: The hook (`04-commit-phase.js --after-ask`) intercepts the approval and triggers Touch ID biometrics to write `user-approval.json`. It then securely stages the files, commits using the signed key, pushes the branch, and programmatically generates a Draft Pull Request on GitHub.

---

## Core Mandates

1. **Zero Data Loss Guarantee:** Destructive Git commands (`git reset --hard`, `git checkout .`, `git clean -fd`) must never be run on uncommitted workspace files unless explicitly requested by the developer, or after backing up work to a temporary branch or the standard backup directory (`~/.gemini/tmp/<repo-name>/backup_changes`).
2. **IDE Review Priority:** Developers review code changes directly in their IDE while they are **unstaged** to maintain color-coded diff visibility. No commits can occur without presenting the unstaged diff and receiving explicit GPG-signed commit approval via the `ask_user` tool.
3. **No Upstream Pushes:** All remote pushes must target the developer's fork, never the upstream "rancher" remote.
4. **Strict Release-Please & SemVer Rules:** All draft commit messages must strictly adhere to Conventional Commits from the end-user product's perspective:
   - **`feat`** (bumping SemVer Minor) and **`refactor`/`!`** (bumping SemVer Major) are strictly reserved for changes directly modifying the Terraform definition files (`main.tf`, `variables.tf`, `versions.tf`, or `outputs.tf`).
   - **Internal Dev Changes:** Changes to helper scripts, CI/CD configuration, linters, internal hooks, or test suites must use non-bumping conventional prefixes such as `build`, `ci`, `test`, `docs`, `fix`, or `chore`.

---

## Step-by-Step Procedure

### Phase 1: Plan Phase (Gate 1)

1. **Research & Explore**: Map the goal and hurdle. Search the codebase for existing patterns and affected source or test files.
2. **Empirical Bug Reproduction**: For bug fixes, write a reproduction script or local test that demonstrates the failure, and run it to confirm the bug state.
3. **Draft Plan**: Draft a step-by-step imperative plan checklist under `~/.gemini/tmp/<repo-name>/<session-id>/plans/`. Explain the implementation details and testing strategy.
4. **Solicit Plan Approval (Gate 1)**: Present the plan in the chat and request cryptographic approval via `ask_user` (using a choice option labeled "Approve Plan"). GPG/Touch ID biometrics sign the plan and write `plan-approval.json`.
5. **Phase Transition**: Call `exit_plan_mode` to transition the session from Plan to Implement.

### Phase 2: Implement Phase (Autonomous)

1. **Surgical Refactoring**: Sequentially implement the tasks from the approved plan, updating the checkboxes in the plan file. Keep edits focused and surgical.
2. **Verification Tests**: Compile and execute tests locally to verify correctness.
3. **Linter & Static Analysis Compliance**: Run ecosystem linters (such as `eslint`, `shellcheck`, and `golangci-lint`) and resolve all warnings.

### Phase 3: Review Phase (Gate 2)

1. **Testing Sign-Off**: Run local test suites to verify full codebase integration, which stores the tested diff_hash in `phase-state.json`.
2. **Delegate Proactive Review**: Run the proactive code review of the active local Git diff by executing `agent-scripts/code-review.js` directly.
3. **Resolve Findings**: The project manager's primary goal is to orchestrate a critical, adversarial peer review. If the subagents flag any architectural gaps or documentation inconsistencies under the `Findings & Comments` section of the report, surgically resolve them and re-run the review until all 4 passes are checked (`- [x]`) and exactly `0 comments/findings` are reported, which allows the enforcer hook to programmatically sign and write `review-approval.json`.

### Phase 4: Commit Phase (Gate 3)

1. **Isolate Changes**: Create a dedicated feature branch off the updated `main`. Keep the changes unstaged in the working directory.
2. **Solicit Commit Approval (Gate 3)**: Present the unstaged diff and request final commit approval via `ask_user` using the proposed conventional commit message format (`Commit Message: "docs: <description>"`).
3. **Automated Commit & Push**: Touch ID biometrics sign `user-approval.json`. The enforcer hook intercepts the approval, stages the changes, commits with the signature, pushes the branch, and programmatically opens a Draft Pull Request on GitHub.
4. **Graduation & Conclude**: Convert the Draft PR to "Ready for Review" via `gh pr ready <pr-number>` once finalized, and cleanly close the session.

---

## Pull Request Iteration & Comment Resolution Protocol

When resolving comments or feedback on an open Pull Request, developers and agents must adhere to the following systematic quality iteration loop:

1. **Update Reference Coding Standards First**: Translate the review comments into strict checking rules and append them to the relevant coding standards file under `docs/development/reference/` (e.g., `Go.md`, `JavaScript.md`, etc.).
2. **Run Map-Reduce Review on Unmodified Codebase**: Run the review orchestrator on the unmodified codebase files. The review pipeline must successfully reproduce the findings in its report and conclude with `PR Review status: 🔴 FINDINGS - Violations detected.`.
3. **Implement Surgical Code Fixes**: Only after the review pipeline successfully reproduces the findings in its local report are you authorized to modify files to address the comments.
4. **Local Verification & Final Review**: Run local linters and tests. Then, execute the review orchestrator one final time to confirm it approves the workspace changes with a clean `PR Review status: 🟢 PERFECT - 0 findings`.
5. **Push Updates & Resolve**: Stage the changes, commit using the Commit Gate, and push to the remote branch. Execute `node agent-scripts/resolve-pr-reviews.js` to programmatically resolve the comment threads on GitHub.
