#!/usr/bin/env bash
set -euo pipefail

# Generic Context Limiter Hook
# Reads JSON from stdin, outputs JSON to stdout. Errors to stderr.

# Read standard input into a variable
payload=$(cat)

# Return allow immediately if payload is empty to prevent jq parsing errors
if [[ -z "$payload" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Extract event and metadata using jq. 
# event_type=$(printf "%s" "$payload" | jq -r '.event // .hook_event_name // "unknown"')
token_usage=$(printf "%s" "$payload" | jq -r '.tokens // 0') # Fallback to 0 if not present
transcript_path=$(printf "%s" "$payload" | jq -r '.transcript_path // ""')

MAX_TOKENS=200000

# Approximate Claude tokens from transcript if .tokens not provided
if [[ "$token_usage" -eq 0 ]] && [[ -n "$transcript_path" ]] && [[ "$transcript_path" != "null" ]] && [[ -f "$transcript_path" ]]; then
  file_size=$(wc -c < "$transcript_path" | tr -d ' ')
  token_usage=$((file_size / 4))
fi

if [[ "$token_usage" -gt "$MAX_TOKENS" ]]; then
  reason="Context limit of $MAX_TOKENS tokens reached. You must halt operations, update plans, and prompt the user for a new session."
  
  # Claude uses hookSpecificOutput to return a deny decision via JSON
  if printf "%s" "$payload" | grep -q '"hook_event_name"'; then
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
if printf "%s" "$payload" | grep -q '"hook_event_name"'; then
  # For Claude, exiting 0 with empty stdout is sufficient to allow normal flow
  exit 0
else
  # Gemini allows proceeding
  echo '{"decision": "allow"}'
fi
