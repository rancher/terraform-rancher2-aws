# Enforce Strict TOML Ask-User Intent Validation

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.
>
> **Diátaxis Archetype**: Reference Manual

---

## Abstract

This document defines the formal reference specification and TOML schemas for `ask_user` tool invocations across all gating transitions in the repository's secure, zero-trust developer environment.

---

## Allowed Intents Allowlist

All automated and collaborative `ask_user` tool calls are checked against a strict, secure allowlist of recognized intents:

1. **`plan approval`**: Requesting developer sign-off on a proposed plan to satisfy Gate 1.
2. **`commit approval`**: Requesting final developer sign-off to sign, commit, and push changes to satisfy Gate 3.
3. **`clarification`**: Requesting architectural, scope, or requirement choices.
4. **`suggest action`**: Proposing a procedural next step or alternative implementation path.

---

## Intent Schemas & Payloads

The `question` field in the `ask_user` tool payload MUST contain a valid TOML document matching the respective schemas below:

### 1. Plan Approval Schema (`plan approval`)

Used at Gate 1 (Planning Gate) to request physical GPG-signed approval of the dynamic plan.

**TOML Schema:**

```toml
intent = "plan approval"
request = "A string representing the sign-off question."
plan = "The complete markdown plan content enclosing the implementation checklist."
```

**Example JSON Tool Payload:**

```json
{
  "questions": [
    {
      "header": "Approve Plan",
      "type": "yesno",
      "question": "intent = \"plan approval\"\nrequest = \"Do you approve the proposed feature plan?\"\nplan = \"\"\"# Plan: Feature X\n- [ ] Task 1\n- [ ] Task 2\n\"\"\""
    }
  ]
}
```

---

### 2. Commit Approval Schema (`commit approval`)

Used at Gate 3 (Commit Gate) to request physical GPG-signed approval of the Conventional Commit.

**TOML Schema:**

```toml
intent = "commit approval"
request = "A string representing the commit sign-off question."
hash = "The SHA-256 hash of the current unstaged Git diff."
"commit-message" = "The proposed Conventional Commit message."
"pr-description" = "The detailed pull request description."
```

**Example JSON Tool Payload:**

```json
{
  "questions": [
    {
      "header": "Approve Commit",
      "type": "yesno",
      "question": "intent = \"commit approval\"\nrequest = \"Do you approve the commit and PR details?\"\nhash = \"a1b2c3d4...\"\ncommit-message = \"feat: add module x\"\npr-description = \"This PR implements module x.\""
    }
  ]
}
```

---

### 3. Clarification Schema (`clarification`)

Used during research or development to obtain technical clarification.

**TOML Schema:**

```toml
intent = "clarification"
request = "The explicit question for the developer."
```

**Example JSON Tool Payload:**

```json
{
  "questions": [
    {
      "header": "Clarification",
      "type": "choice",
      "options": [
        { "label": "Option A", "description": "Choose option A" },
        { "label": "Option B", "description": "Choose option B" }
      ],
      "question": "intent = \"clarification\"\nrequest = \"Which option should we proceed with?\""
    }
  ]
}
```

---

### 4. Suggest Action Schema (`suggest action`)

Used to suggest procedural resolutions or course-corrections.

**TOML Schema:**

```toml
intent = "suggest action"
request = "The description of the suggested action."
```

**Example JSON Tool Payload:**

```json
{
  "questions": [
    {
      "header": "Action Proposal",
      "type": "choice",
      "options": [
        { "label": "Yes", "description": "Execute suggested action" },
        { "label": "No", "description": "Skip suggested action" }
      ],
      "question": "intent = \"suggest action\"\nrequest = \"Would you like to resolve the current findings automatically?\""
    }
  ]
}
```

---

## Validation Failure & Rejections

If a tool call is executed with an invalid TOML structure or an unrecognized intent, the validation engine immediately blocks execution and returns a structured fail-forward response. This response details:

1. The exact syntax error.
2. The mismatched schema parameter.
3. Actionable remediation steps with reference templates.
