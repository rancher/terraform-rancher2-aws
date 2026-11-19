#!/usr/bin/env bash
# Wrapper script to exercise models in the correct environment

set -euo pipefail

show_help() {
  cat <<EOF
Usage: exercise-cron.sh [options]

Wrapper script to exercise models in the correct environment for headless cron execution.

Options:
  -h, --help    Show this help message and exit
EOF
}

# parse_args handles the command-line argument contract.
# Note: This is intentionally simplified to support a single-parameter contract
# (specifically checking for -h/--help) and does not support multi-argument shifting.
parse_args() {
  case "${1:-}" in
    -h | --help)
      show_help
      exit 0
      ;;
    "")
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      show_help
      exit 1
      ;;
  esac
}

run_exercise() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  local repo_root
  repo_root="$(cd "${script_dir}/../.." >/dev/null 2>&1 && pwd)"

  # Ensure Nix binaries are reachable in non-interactive cron environments
  export PATH="${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"

  local run_in_nix="${repo_root}/.dev/nix-run.sh"
  if [[ ! -x "${run_in_nix}" && -x "${repo_root}/nix-run.sh" ]]; then
    run_in_nix="${repo_root}/nix-run.sh"
  elif [[ ! -x "${run_in_nix}" && -x "${repo_root}/.dev/run-in-nix.sh" ]]; then
    run_in_nix="${repo_root}/.dev/run-in-nix.sh"
  elif [[ ! -x "${run_in_nix}" && -x "${repo_root}/run-in-nix.sh" ]]; then
    run_in_nix="${repo_root}/run-in-nix.sh"
  fi

  if [[ ! -x "${run_in_nix}" ]]; then
    echo "Error: run-in-nix script not found or not executable" >&2
    exit 1
  fi

  cd "${repo_root}"

  # Execute exercise-agents.js within the Nix environment
  "${run_in_nix}" node "${script_dir}/exercise-agents.js"
}

main() {
  parse_args "$@"
  run_exercise
}

main "$@"
