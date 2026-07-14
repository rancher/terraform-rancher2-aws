# Temporary Plan: Context Limit Enforcement Hook

**Status:** Completed

## Execution Steps
- [x] Create the hook script at `.agent/hooks/check-context.sh`.
  - Enforce `shell-scripts.instructions.md` standards (e.g., `set -euo pipefail`, `#!/usr/bin/env bash`, proper variable quoting).
- [x] Update `.gemini/settings.json` to register the new hook for `BeforeTool` and `BeforeToolSelection` events.
- [x] Update `.claude/settings.json` to register the `PreToolUse` hook.
- [x] Update `.agent/plans/ContextLimitEnforcementHook.md` to mark the plan as completed with the current date.

## Notes
- If context limits reach 25% or 200,000 tokens during execution, operations must be paused, and this plan updated.
