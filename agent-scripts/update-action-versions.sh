#!/usr/bin/env bash
#
# Skill: update-action-versions.sh
# Description: Automatically audits and updates the commit SHAs and version tags of GitHub Actions workflows to the latest available releases.
# Usage: agent-scripts/update-action-versions.sh

set -euo pipefail

show_help() {
  cat <<EOF
Usage: update-action-versions.sh [options]

Automatically audits and updates the commit SHAs and version tags of GitHub Actions workflows
to their latest available releases.

Options:
  --list-actions       List all actions used in workflow files and their current versions.
  -h, --help           Show this help message and exit.

Examples:
  agent-scripts/update-action-versions.sh --list-actions
  agent-scripts/update-action-versions.sh
EOF
}

# Safely executes a command with retry and exponential backoff
run_with_retry() {
  local max_attempts=5
  local base_delay=2
  local attempt=1
  local exit_code=0

  while true; do
    if "${@}"; then
      return 0
    else
      exit_code="${?}"
    fi

    if [[ "${attempt}" -ge "${max_attempts}" ]]; then
      echo "Error: Command '${*}' failed after ${max_attempts} attempts." >&2
      return "${exit_code}"
    fi

    local delay
    delay=$(( base_delay * (2 ** (attempt - 1)) ))
    echo "Warning: Command failed (exit code ${exit_code}). Retrying in ${delay} seconds (attempt ${attempt}/${max_attempts})...." >&2
    sleep "${delay}"
    attempt=$((attempt + 1))
  done
}

# Fetches the latest release tag from GitHub API with safety connect-timeouts and HTTP fail flags
get_latest_release() {
  local action="${1}"
  local repo
  repo=$(echo "${action}" | cut -d'/' -f1,2)

  local api_url="https://api.github.com/repos/${repo}/releases/latest"
  local response
  if response=$(curl -s -f --connect-timeout 5 "${api_url}" 2>/dev/null); then
    local tag
    tag=$(echo "${response}" | grep -o '"tag_name": *"[^"]*"' | head -n1 | cut -d'"' -f4)
    if [[ -n "${tag}" ]]; then
      echo "${tag}"
      return 0
    fi
  fi
  return 1
}

list_current_actions() {
  local search_dir=".github/workflows"
  echo "Scanning GitHub Actions workflow files to list action usages and versions..." >&2

  local actions_data
  # shellcheck disable=SC2016
  actions_data=$(find "${search_dir}" -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 2>/dev/null \
    | xargs -0 awk '
      /[[:space:]]+uses:[[:space:]]+/ {
        str = $0
        sub(/^[[:space:]]*uses:[[:space:]]*/, "", str)
        comment = ""
        
        if (str ~ /#/) {
          idx = index(str, "#")
          comment = substr(str, idx + 1)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", comment)
          str = substr(str, 1, idx - 1)
          gsub(/[[:space:]]+$/, "", str)
        }
        
        split(str, parts, "@")
        action = parts[1]
        ver = parts[2]
        
        # Strip quotes and carriage returns safely
        gsub(/["\047\r]/, "", action)
        gsub(/["\047\r]/, "", ver)
        
        if (action ~ /\// && ver != "") {
          filename_clean = FILENAME
          sub(/^.*\.github\/workflows\//, "", filename_clean)
          print action "\t" ver "\t" (comment != "" ? comment : "N/A") "\t" filename_clean
        }
      }
    ' 2>/dev/null || echo "")

  if [[ -z "${actions_data}" ]]; then
    echo "No GitHub Actions references found in workflow files." >&2
    return 0
  fi

  echo "${actions_data}" | sort | awk -F'\t' '
    BEGIN {
      printf "%-38s %-43s %-15s %s\n", "ACTION", "COMMIT SHA / REF", "RELEASE", "FILE"
      printf "========================================================================================================================\n"
    }
    {
      printf "%-38s %-43s %-15s %s\n", $1, $2, $3, $4
    }
  '
}

# Audits and updates all workflow action versions
update_workflow_actions() {
  local search_dir=".github/workflows"
  local file
  local action_ref
  echo "Starting GitHub Actions workflow version audits..."

  # Avoid stdin redirection conflict by using a dedicated file descriptor '3'
  while IFS= read -r -d '' file <&3; do
    echo "Auditing workflow file: ${file}"

    # Temporary file for atomic writing
    local temp_file
    temp_file="${file}.tmp"
    cp "${file}" "${temp_file}"

    # Extract all action uses
    local actions
    actions=$(grep -oE "uses: *['\"]?[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+@[^'\"\r\n]+" "${file}" | sed -E "s/uses: *['\"]?//g" || true)

    # shellcheck disable=SC2086
    for action_ref in ${actions}; do
      local action_name
      action_name=$(echo "${action_ref}" | cut -d'@' -f1)
      local current_ver
      current_ver=$(echo "${action_ref}" | cut -d'@' -f2 | tr -d "'\"\r")

      # Fetch latest tag
      local latest_ver
      if latest_ver=$(get_latest_release "${action_name}"); then
        if [[ "${current_ver}" != "${latest_ver}" ]]; then
          echo "  -> Updating ${action_name}: ${current_ver} -> ${latest_ver}"
          # Secure and portable sed in-place replacement
          if [[ "$(uname)" == "Darwin" ]]; then
            sed -i "" "s|uses: *['\"]*${action_name}@${current_ver}['\"]*|uses: ${action_name}@${latest_ver}|g" "${temp_file}"
          else
            sed -i "s|uses: *['\"]*${action_name}@${current_ver}['\"]*|uses: ${action_name}@${latest_ver}|g" "${temp_file}"
          fi
        fi
      fi
    done

    mv "${temp_file}" "${file}"
  done 3< <(find "${search_dir}" -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 2>/dev/null)

  echo "Workflow version audit complete."
}

parse_args() {
  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
      -h|--help)
        show_help
        exit 0
        ;;
      --list-actions)
        LIST_ACTIONS="true"
        shift
        ;;
      -*)
        echo "Error: Unknown option: ${1}" >&2
        show_help
        exit 1
        ;;
      *)
        echo "Error: Unexpected argument: ${1}" >&2
        show_help
        exit 1
        ;;
    esac
  done
}

main() {
  # Dynamically scoped local variable visible to parse_args
  local LIST_ACTIONS="false"
  parse_args "${@}"

  if [[ "${LIST_ACTIONS}" == "true" ]]; then
    list_current_actions
    exit 0
  fi

  update_workflow_actions
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "${@}"
fi
