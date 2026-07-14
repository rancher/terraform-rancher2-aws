# Context Limit Enforcement Hook

**Executed Date:** 2026 August
**Purpose:** Implement a generic CLI hook in `.agent/hooks/` to automatically monitor and enforce context limits (e.g., 200,000 tokens) for agents like Gemini and Claude, preventing them from exceeding maximum token sizes and degrading performance.

## Goals
1. Develop a context-checking hook in `.agent/hooks/check-context.sh`.
2. Parse the session context usage and block further tool execution if token usage exceeds a defined threshold (e.g., 200,000 tokens).
3. Ensure the core checking logic is generic enough to be run manually or integrated by Claude for similar token-monitoring.
4. Update or create `.gemini/settings.json` and `.claude/settings.json` to register the hook for the workspace.

## Implementation Details

### 1. The Hook Script
We will place the hook logic in `.agent/hooks/check-context.sh`. It will be an executable shell script that uses `jq` to parse the standard input provided by the agent runtime. This makes it light and portable.
For Claude, if `.tokens` is not available, we can approximate the token count using the file size of the provided `.transcript_path`.

**Code Snippet (`.agent/hooks/check-context.sh`):**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Generic Context Limiter Hook
# Reads JSON from stdin, outputs JSON to stdout. Errors to stderr.

# Read standard input into a variable
payload=$(cat)

# Extract event and metadata using jq. 
# (The exact JSON paths will be finalized during implementation based on the active CLI tool's payload)
event_type=$(echo "$payload" | jq -r '.event // .hook_event_name // "unknown"')
token_usage=$(echo "$payload" | jq -r '.tokens // 0') # Fallback to 0 if not present
transcript_path=$(echo "$payload" | jq -r '.transcript_path // ""')

MAX_TOKENS=200000

# Approximate Claude tokens from transcript if .tokens not provided
if [[ "$token_usage" -eq 0 ]] && [[ -n "$transcript_path" ]] && [[ "$transcript_path" != "null" ]] && [[ -f "$transcript_path" ]]; then
  file_size=$(wc -c < "$transcript_path" | tr -d ' ')
  token_usage=$((file_size / 4))
fi

if [[ "$token_usage" -gt "$MAX_TOKENS" ]]; then
  reason="Context limit of $MAX_TOKENS tokens reached. You must halt operations, update plans, and prompt the user for a new session."
  
  # Claude uses hookSpecificOutput to return a deny decision via JSON
  if echo "$payload" | grep -q '"hook_event_name"'; then
    jq -n --arg reason "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  else
    # Gemini CLI hooks return control decisions
    jq -n --arg reason "$reason" '{
      "decision": "deny",
      "reason": $reason
    }'
    exit 0
  fi
fi

# Allow operation to proceed if limit is not breached
if echo "$payload" | grep -q '"hook_event_name"'; then
  # For Claude, we just exit 0 to allow normal permission flow, 
  # or we can output a generic json allowing it. Exiting 0 with empty stdout is sufficient or we can just print empty JSON.
  exit 0
else
  # Gemini allows proceeding
  echo '{"decision": "allow"}'
fi
```

### 2. Gemini Hook Configuration
We will add the configuration to the local `.gemini/settings.json` to wire the hook into the Gemini CLI lifecycle, specifically hooking into tool execution to prevent long-running tasks from spiraling context.

**Code Snippet (`.gemini/settings.json`):**
```json
{
  "hooks": [
    {
      "events": ["BeforeTool", "BeforeToolSelection"],
      "command": "bash",
      "args": [".agent/hooks/check-context.sh"],
      "description": "Enforces maximum context token limit to prevent execution failures"
    }
  ]
}
```

### 3. Claude Hook Configuration
For Claude, we configure a `PreToolUse` hook in `.claude/settings.json`.

**Code Snippet (`.claude/settings.json`):**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash",
            "args": [".agent/hooks/check-context.sh"],
            "timeout": 600
         }
        ]
      }
    ]
  }
}
```
