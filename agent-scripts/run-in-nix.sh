#!/usr/bin/env bash
#
# Skill: run-in-nix.sh
# Description: Executes a given command inside the standardized Nix development environment, or lists installed tools.
# Usage: agent-scripts/run-in-nix.sh "<command>"

set -euo pipefail

show_help() {
  cat <<EOF
Usage: run-in-nix.sh [options] "<command>"

Executes a given command inside the standardized Nix development environment, or queries installed tools.

Options:
  --list-tools         List all executable tools installed in the Nix development shell and exit.
  -h, --help           Show this help message and exit.

Examples:
  agent-scripts/run-in-nix.sh --list-tools
  agent-scripts/run-in-nix.sh "terraform validate"
  agent-scripts/run-in-nix.sh "go test ./..."
EOF
}

readonly NIX_BIN="/nix/var/nix/profiles/default/bin/nix"

query_nix_tools() {
  echo "Querying standard Nix environment for installed tools..." >&2

  # Execute a inline script inside Nix shell to find the dev-shell-package/bin directory on the PATH
  local bin_dir
  if [[ -n "${IN_NIX_SHELL:-}" ]]; then
    bin_dir=$(echo "${PATH}" | tr ":" "\n" | grep "dev-shell-package/bin" | head -n 1 || echo "")
  else
    # shellcheck disable=SC2016
    bin_dir=$("${NIX_BIN}" develop \
      --extra-experimental-features nix-command \
      --extra-experimental-features flakes \
      --command bash -c 'echo "$PATH" | tr ":" "\n" | grep "dev-shell-package/bin" | head -n 1' 2>/dev/null || echo "")
  fi

  if [[ -z "${bin_dir}" || ! -d "${bin_dir}" ]]; then
    echo "Error: Could not locate dev-shell-package/bin in the Nix environment." >&2
    exit 1
  fi

  echo "Installed Nix Tools:"
  echo "===================="
  # List all files in the symlink directory, filtering out internal dot-prefixed executables
  find "${bin_dir}" -maxdepth 1 -type l -not -name ".*" -exec basename "{}" \; | sort
}

execute_in_nix() {
  if [[ -n "${IN_NIX_SHELL:-}" ]]; then
    echo "Already in a Nix shell environment (IN_NIX_SHELL=${IN_NIX_SHELL}). Executing command directly..." >&2
    bash -c "$*"
    return
  fi

  echo "Running command in Nix environment: $*" >&2

  "${NIX_BIN}" develop \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    --command bash -c "$*"
}

parse_args() {
  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
      -h|--help)
        show_help
        exit 0
        ;;
      --list-tools)
        LIST_TOOLS="true"
        shift
        ;;
      -*)
        echo "Error: Unknown option: ${1}" >&2
        show_help
        exit 1
        ;;
      *)
        COMMAND_ARGS=("${@}")
        break
        ;;
    esac
  done
}

main() {
  # Dynamically scoped local variable visible to parse_args
  local LIST_TOOLS="false"
  local -a COMMAND_ARGS=()

  parse_args "${@}"

  if [[ "${LIST_TOOLS}" == "true" ]]; then
    query_nix_tools
    exit 0
  fi

  if [[ "${#COMMAND_ARGS[@]}" -eq 0 ]]; then
    echo "Error: Command required." >&2
    show_help
    exit 1
  fi

  execute_in_nix "${COMMAND_ARGS[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
