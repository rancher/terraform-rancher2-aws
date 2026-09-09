# PR review comment resolution

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

---

## Abstract

This component defines our high-standard engineering process for analyzing, planning, and executing resolutions for Pull Request review comments in a dedicated development session.

---

## Purpose

Review comments from human maintainers and automated bots provide valuable insights. This workflow enforces a **"Discernment-First"** protocol: AI agents must analyze the _underlying concerns_, critically evaluate if they are valid, design high-quality, standard-compliant solutions, post clear responses to each thread on GitHub, and programmatically resolve them after refactoring.

---

## Detailed step-by-step procedure

### 1. Retrieve comments

- First, retrieve a chronological timeline of all general and inline review comments:

  ```bash
  agent-scripts/get-pr-comments.sh [PR_ID]
  ```

- Analyze the timeline to map file paths, lines, authors, and feedback.

### 2. Separation of concerns and evaluation (discernment phase)

For each comment retrieved, perform a critical architectural assessment:

- **Evaluate validity**: Is there an actual logic flaw, security vulnerability, syntax error, or style deviation?
  - **If valid**: Acknowledge the concern and design a custom, idiomatic fix conforming to `docs/development/reference/`.
  - **If invalid**: Prepare a clear, professional, and technical explanation why the current implementation is correct.
- **Reject automated recommendations**: Never blindly copy sub-optimal recommendations, workarounds that disable warnings, or "soft-failure" defaults that mask configuration errors.

### 3. Update active plan

Before making any file edits, adapt the active plan under `plans/` in the session workspace to document the comments:

- Add a dedicated comment resolution section mapping out the evaluated concerns and custom solutions.
- Append corresponding task checkboxes to the plan's checklist.

### 4. Respond to comment threads on GitHub

To maintain high collaboration standards, post an explicit response to each comment thread on GitHub before or during the fix:

- Explain your technical evaluation and solution, or provide your counter-rational if the concern is invalid.
- _(Note: Response comments can be posted using native GitHub CLI or discussion APIs)._

### 5. Surgical refactoring and verification

Implement and verify changes autonomously off the approved plan:

- **Act surgically**: Touch only the necessary files.
- **Validate thoroughly**: Run local linters (`eslint`, `shellcheck`), compilers, and test suites (`make test`) to ensure exactly 0 findings and 0 regressions.

### 6. Secure commit and push

Once verified, present the unstaged diff and request approval via `ask_user` (format: `Commit Message: "fix(hooks): resolve review findings on PR #<id>"`). The hook will automatically write the signature, commit, push, and update the PR on GitHub.

### 7. Programmatic thread resolution

Once changes are pushed and verified on GitHub, programmatically resolve all comment threads on GitHub:

```bash
agent-scripts/resolve-pr-reviews.sh [PR_ID] --bypass-token --all
```

Verify that all threads are fully closed on GitHub, concluding the resolution session.
