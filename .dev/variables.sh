#!/usr/bin/env bash
#
# Helper: variables.sh
# Description: Environment variables and prompt configuration for development shell.

export TF_IN_AUTOMATION=1
# Use clean single quotes to define PS1 so command substitutions are evaluated dynamically by the shell
export PS1='$(blue)$(get_repo_owner)/$(ce)$(orange)\W $(ce)$(git_status) '
# Set the system prompt
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export GEMINI_SYSTEM_MD="${REPO_ROOT}/.gemini/system.md"
