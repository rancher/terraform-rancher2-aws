#!/usr/bin/env bash
#
# Helper: rc.sh
# Description: Sources environment variables, functions, and aliases for the development shell.

if [[ -n "${DEV_INTERACTIVE:-}" ]]; then
  interactive="${DEV_INTERACTIVE}"
elif [[ $- == *i* ]]; then
  interactive=1
else
  interactive=0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i | --interactive)
      interactive=1
      shift
      ;;
    -n | --non-interactive)
      interactive=0
      shift
      ;;
    -h | --help)
      cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [options]

Sources environment variables, functions, and aliases for the development shell.

Options:
  -i, --interactive       Load full interactive environment (default)
  -n, --non-interactive   Load only non-interactive environment variables and credentials
  -h, --help              Show this help message and exit
EOF
      return 0 2>/dev/null || exit 0
      ;;
    *)
      break
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DEV_DIR="${REPO_ROOT}/.dev"

# Configuration: List of files to source in evaluation order.
# Format: "<mode>:<path>"
#   all         - Sourced in both interactive and non-interactive sessions
#   interactive - Sourced only when interactive mode is active
rc_files=(
  "all:${DEV_DIR}/variables.sh"
  "interactive:${DEV_DIR}/functions.sh"
  "interactive:${DEV_DIR}/aliases.sh"
  "interactive:${HOME}/.config/functions/default"
  "interactive:${HOME}/.config/alias/default"
  "interactive:${HOME}/.config/github/interactive"
  "all:${HOME}/.config/github/default"
  "all:${HOME}/.config/aws/default"
  "all:${HOME}/.config/gemini/default"
  "all:${DEV_DIR}/rc.local.sh"
)

for entry in "${rc_files[@]}"; do
  mode="${entry%%:*}"
  target="${entry#*:}"

  if [[ "${mode}" == "interactive" && "${interactive}" -ne 1 ]]; then
    continue
  fi

  if [[ -f "${target}" ]]; then
    # shellcheck source=/dev/null
    source "${target}"
  fi
done
