# 💬 Ask User Component

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

---

## Abstract

The `ask_user` tool is the primary mechanism for the autonomous agent to collaborate with, ask clarification questions of, or obtain cryptographically signed approvals from the human developer. To prevent parsing ambiguity, maintain structured history, and guarantee robust automation validation, **all `ask_user` tool calls must be formatted as structured TOML payloads.**

---

## 📋 Strict Intent Allowlist

All `ask_user` tool calls are strictly validated. You MUST set the `intent` field to one of the following recognized, allowed intents. Any unrecognized intent will result in the tool execution being immediately **denied**.

| Intent            | Purpose                                                                        | Mandatory Fields                                                |
| :---------------- | :----------------------------------------------------------------------------- | :-------------------------------------------------------------- |
| `plan approval`   | Requesting the human developer's sign-off on the step-by-step plan.            | `intent`, `request`, `plan`                                     |
| `commit approval` | Requesting final sign-off to sign, commit, and push changes to GitHub.         | `intent`, `request`, `hash`, `commit-message`, `pr-description` |
| `clarification`   | Asking the developer for technical details, choices, or architectural clarity. | `intent`, `request`                                             |
| `suggest action`  | Proposing a specific path forward or resolving a technical hurdle.             | `intent`, `request`                                             |

---

## 📋 Schema Requirements

Every `ask_user` request must format its question string as a valid, well-formed TOML document.

### 1. General Fields (Required for All Requests)

- `intent` (string): The clear, categorized purpose of the request (must match one of the allowed intents above).
- `request` (string): The actual question, description, or prompt being presented to the human developer.
- **Strict Question Type Enforcement:** For `plan approval` and `commit approval` intents, the `type` parameter of the `ask_user` tool call's question object MUST be set strictly to `"yesno"` (binary yes/no prompt). This completely eliminates guesswork and ensures 100% deterministic parsing of the response.

### 2. Plan Approval Specific Fields (Required when `intent = "plan approval"`)

- `plan` (string, multi-line markdown): The complete implementation and testing checklist plan drafted under `plans/`. This must be a well-formed markdown string.

### 3. Commit Approval Specific Fields (Required when `intent = "commit approval"`)

- `hash` (string): The git diff SHA/hash produced during the review phase (using `calculateDiffHash()`) that the developer is approving.
- `commit-message` (string): The exact, conventional commit message to use for the automated git commit.
- `pr-description` (string, markdown): The detailed description of the pull request to use when programmatically opening the PR.

---

## 🛠️ Example Tool Call Payload

When invoking the `ask_user` tool, the entire TOML string is passed as the `question` field value inside the `questions` array parameter.

```json
{
  "questions": [
    {
      "question": "intent = \"clarification\"\nrequest = \"What branch should I create this PR from?\"",
      "header": "Branch question",
      "type": "choice",
      "options": [
        { "label": "main", "description": "Merge directly into main branch" },
        { "label": "feature", "description": "Merge into feature branch" }
      ]
    }
  ]
}
```

---

## 💡 Templates & Examples

The following templates represent the correct formatting required for each intent. When using the `ask_user` tool, copy and populate the appropriate block exactly.

### 1. Plan Approval (`plan approval`)

Use this intent when asking for cryptographic plan approval at Gate 1.

```toml
intent = "plan approval"
request = "I have drafted the plan for implementing the TOML validation feature. Do you cryptographically approve this plan so that I can exit Plan Mode and begin writing the code?"
plan = """
# Enforce TOML Format for ask_user Tool

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). No phase or gate may be bypassed.

## Objective
Update the Agentic Framework to formalize all `ask_user` tool inputs into a structured TOML format...

## Implementation Steps
- [ ] Install `@iarna/toml`
- [ ] Create `.gemini/hooks/ask-user-toml-validator.js`
- [ ] Configure `settings.json`
"""
```

### 2. Commit Approval (`commit approval`)

Use this intent when requesting final sign-off to commit and push changes at Gate 3.

```toml
intent = "commit approval"
request = "My automated testing and review checks have completed successfully, and I have generated a candidate commit message. Do you approve these changes for commit?"
hash = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0"
commit-message = "feat: implement structured TOML ask_user hooks"
pr-description = """
This PR introduces structured TOML validation for all `ask_user` tool calls.

### Changes
- Created `ask-user-toml-validator.js` enforcer hook.
- Integrated validation in `settings.json`.
- Modified plan and commit phase hooks to parse TOML.
"""
```

### 3. Clarification (`clarification`)

Use this intent when you need to resolve structural choices or ambiguities in the requirements.

```toml
intent = "clarification"
request = "I see multiple testing folders under `test/`. Should I place our new integration tests under `test/local/basic/` or create a new directory?"
```

### 4. Suggest Action (`suggest action`)

Use this intent when you hit an obstacle or have multiple paths forward, and want to suggest the best option.

```toml
intent = "suggest action"
request = "I encountered a dependency conflict with library X. I suggest either (1) upgrading library X to version 2.0 or (2) refactoring our utility to avoid using X. I recommend upgrading X because it is cleaner. How should I proceed?"
```

---

## 🔒 Violation & Enforcement

Any `ask_user` tool call that is not well-formed TOML, is missing required fields (such as `intent` or `request`), or uses an unrecognized `intent` will be immediately rejected with a `deny` decision by our pre-tool enforcer hooks.

If your tool call is blocked:

1. Review the validation error returned by the hook.
2. Ensure you have formatted your prompt inside `questions[0].question` or `question` exactly as a TOML document.
3. Use triple-quotes (`"""`) for multiline strings (such as plans).
4. Verify all mandatory keys are provided for your specific `intent`.
5. Ensure your `intent` matches one of our 4 strictly allowed values.
6. Ensure your tool call `type` parameter is set strictly to `"yesno"` if you are requesting a plan or commit approval.
