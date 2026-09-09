#!/usr/bin/env bash
#
# Skill: update-modules.sh
# Description: Dynamically detects and updates all Terraform Registry module references in all .tf files to their latest registry versions.
# Usage: agent-scripts/update-modules.sh

set -euo pipefail

show_help() {
  cat <<EOF
Usage: update-modules.sh [options]

Scans all Terraform (.tf) files, dynamically extracts all unique public registry module references
(format: namespace/name/provider), queries the Terraform Registry API with automatic retry/backoff,
and updates their version parameters to the latest available releases.

Options:
  --list-modules       List all modules declared in Terraform files and their current versions.
  -h, --help           Show this help message and exit.

Examples:
  agent-scripts/update-modules.sh --list-modules
  agent-scripts/update-modules.sh
EOF
}

# Safely executes a command with retry and exponential backoff
run_with_retry() {
  local max_attempts=5
  local base_delay=2
  local attempt=1
  local exit_code=0

  while true; do
    if "$@"; then
      return 0
    else
      exit_code=$?
    fi

    if [[ "${attempt}" -ge "${max_attempts}" ]]; then
      echo "Error: Command '$*' failed after ${max_attempts} attempts." >&2
      return "${exit_code}"
    fi

    local delay
    delay=$(( base_delay * (2 ** (attempt - 1)) ))
    echo "Warning: Command failed (exit code ${exit_code}). Retrying in ${delay} seconds (attempt ${attempt}/${max_attempts})..." >&2
    sleep "${delay}"
    attempt=$((attempt + 1))
  done
}

get_latest_version() {
  local module_name="${1}"
  local status_code
  
  status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://registry.terraform.io/v1/modules/${module_name}" 2>/dev/null || echo "000")
  if [[ "${status_code}" == "404" ]]; then
    echo "Warning: Module ${module_name} not found (HTTP 404). Skipping." >&2
    return 1
  fi

  local latest_version
  # Connect-timeout, fail on HTTP errors (-f), and safe API calls
  latest_version=$(run_with_retry curl -s -f --connect-timeout 5 "https://registry.terraform.io/v1/modules/${module_name}" 2>/dev/null | jq -r '.version // empty')
  
  if [[ -z "${latest_version}" || "${latest_version}" == "null" ]]; then
    return 1
  fi
  
  echo "${latest_version}"
}

list_current_modules() {
  local search_dir="."
  echo "Scanning Terraform files to list module instances and versions..." >&2

  local modules_data
  # Robust HCL-like block parsing using stateful AWK
  # shellcheck disable=SC2016
  modules_data=$(find "${search_dir}" -type d \( -name ".git" -o -name ".terraform" -o -name "tf_plugin_cache" \) -prune -o -type f -name "*.tf" -print0 2>/dev/null \
    | xargs -0 awk '
      BEGIN {
        mod_name = ""
        source_val = ""
        ver_val = ""
      }
      $1 == "module" && $2 ~ /^"[A-Za-z0-9_-]+"/ {
        split($2, parts, "\"")
        mod_name = parts[2]
        source_val = ""
        ver_val = ""
      }
      $1 == "source" && mod_name != "" {
        split($0, parts, "\"")
        source_val = parts[2]
      }
      $1 == "version" && mod_name != "" {
        split($0, parts, "\"")
        ver_val = parts[2]
      }
      $1 == "}" && mod_name != "" {
        gsub(/[\r]/, "", source_val)
        gsub(/[\r]/, "", ver_val)
        if (source_val ~ /^[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+$/) {
          filename_clean = FILENAME
          sub(/^\.\//, "", filename_clean)
          print mod_name "\t" source_val "\t" (ver_val != "" ? ver_val : "N/A") "\t" filename_clean
        }
        mod_name = ""
        source_val = ""
        ver_val = ""
      }
    ' 2>/dev/null || echo "")

  if [[ -z "${modules_data}" ]]; then
    echo "No module references found in Terraform files." >&2
    return 0
  fi

  echo "${modules_data}" | sort | awk -F'\t' '
    BEGIN {
      printf "%-18s %-32s %-18s %s\n", "MODULE", "SOURCE", "VERSION", "FILE"
      printf "%s\n", "----------------------------------------------------------------------------------------"
    }
    {
      printf "%-18s %-32s %-18s %s\n", $1, $2, $3, $4
    }
  '
}

update_modules() {
  local search_dir="."
  local file
  local source_val
  echo "Starting Terraform Registry module version audits..."

  # Dedicated file descriptor '3' to prevent stdin redirection conflicts
  while IFS= read -r -d '' file <&3; do
    echo "Auditing Terraform file: ${file}"

    local temp_file
    temp_file="${file}.tmp"
    cp "${file}" "${temp_file}"

    # Extract unique module sources
    local modules
    modules=$(awk '
      $1 == "source" {
        split($0, parts, "\"")
        src = parts[2]
        gsub(/[\r]/, "", src)
        if (src ~ /^[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+$/) {
          print src
        }
      }
    ' "${file}" | sort -u)

    # shellcheck disable=SC2086
    for source_val in ${modules}; do
      local latest_ver
      if latest_ver=$(get_latest_version "${source_val}"); then
        echo "  -> Found latest version for ${source_val}: ${latest_ver}"
        # Robust, multi-line and macOS-safe stateful buffered AWK replacement
        awk -v src="${source_val}" -v new_ver="${latest_ver}" '
          BEGIN {
            in_module = 0
            buf_idx = 0
          }
          $1 == "module" {
            in_module = 1
            buf_idx = 0
            matched_src = 0
            version_idx = 0
          }
          in_module {
            buf_idx++
            buf[buf_idx] = $0
            if ($1 == "source") {
              split($0, parts, "\"")
              if (parts[2] == src) {
                matched_src = 1
              }
            }
            if ($1 == "version") {
              version_idx = buf_idx
            }
            if ($1 == "}") {
              if (matched_src && version_idx > 0) {
                sub(/"[^"]+"/, "\"" new_ver "\"", buf[version_idx])
              }
              for (i = 1; i <= buf_idx; i++) {
                print buf[i]
              }
              in_module = 0
            }
            next
          }
          { print }
        ' "${temp_file}" > "${temp_file}.tmp" && mv "${temp_file}.tmp" "${temp_file}"
      fi
    done

    mv "${temp_file}" "${file}"
  done 3< <(find "${search_dir}" -type d \( -name ".git" -o -name ".terraform" -o -name "tf_plugin_cache" \) -prune -o -type f -name "*.tf" -print0 2>/dev/null)

  echo "Terraform module version audit complete."
}

parse_args() {
  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
      -h|--help)
        show_help
        exit 0
        ;;
      --list-modules)
        list_modules=true
        shift
        ;;
      *)
        echo "Error: Unknown option: ${1}" >&2
        show_help
        exit 1
        ;;
    esac
  done
}

main() {
  # Dynamically scoped local variable visible to parse_args
  local list_modules=false
  parse_args "${@}"

  if [[ "${list_modules}" == "true" ]]; then
    list_current_modules
  else
    update_modules
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
