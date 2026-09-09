# How to Integrate and Configure Claude Code

This guide provides step-by-step instructions to integrate Claude Code with our Gated 4-Phase Lifecycle in parallel with Gemini CLI.

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured goal-oriented how-to task guide of **How to Integrate and Configure Claude Code** within this repository. It establishes the clinical parameters, design rules, and operational constraints for this system area, ensuring standard-compliant environment initialization and developer safety.

---

## Prerequisites

1. Install `claude` (Claude Code CLI).
2. Generate or verify that your cryptographic keys exist under `~/.gemini/` by following the **[Cryptographic Gating & Approvals](../reference/GatingAndApprovals.md)** reference.

---

## Step 1: Initialize the Claude Configuration Directory

Create the required configuration directories for Claude Code:

```bash
mkdir -p ~/.claude
mkdir -p .claude/hooks
```

---

## Step 2: Reference Enrolled Key Material

To authorize Claude Code to sign phase transitions, configure Claude to reference the enrolled Secure Enclave / Touch ID public key directly from the `.gemini` directory without duplicating any key material:

```bash
export AGENT_PUBLIC_KEY="$HOME/.gemini/age-key.pub"
```

---

## Step 3: Configure Claude-Specific Environment Variables

Ensure the verification scripts resolve their state from Claude's temporary directory instead of Gemini's directory:

```bash
export AGENT_STATE_DIR="$HOME/.claude/tmp/terraform-provider-file"
mkdir -p "$AGENT_STATE_DIR"
```

---

## Step 4: Copy Gating Hooks to Claude Configuration

Align the Claude Code workflow gating with our standard system hooks by copying the JS hooks to the `.claude` configuration path:

```bash
cp .gemini/hooks/01-startup-context.js .claude/hooks/session-start-context.js
cp .gemini/hooks/02-plan-phase.js .claude/hooks/sign-plan-gate.js
cp .gemini/hooks/04-commit-phase.js .claude/hooks/gate-before-commit-ask.js
```

---

## Step 4.5: Configure Phase 3 (Review / Gate 2) Integration

Phase 3 is automated and programmatic. To run our proactive Map-Reduce Code Review pipeline within the Claude environment, execute `code-review.js` directly. This invokes the sandboxed review subagents and writes the programmatic `review-approval.json` signature to your `$AGENT_STATE_DIR` path:

```bash
node agent-scripts/code-review.js
```

If any validation blockages or code-review findings exist, the orchestrator writes an itemized remediation checklist to `$AGENT_STATE_DIR/remediation-report.md`. Claude Code can then parse and resolve these findings before re-submitting.

---

## Step 5: Execute and Validate a Standard Change

Follow these sequential tasks to verify the integration:

1. Start a new Claude Code session in the workspace.
2. Enter Claude's native Plan Mode to draft a target plan checklist.
3. Approve the native `ExitPlanMode` tool to sign the Planning Gate (Gate 1).
4. Implement the requested code changes on disk.
5. Run the local review verification suite:

   ```bash
   node agent-scripts/code-review.js
   ```

6. Verify that `review-approval.json` and `plan-approval.json` are present in your `$AGENT_STATE_DIR` directory.
