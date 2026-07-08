#!/usr/bin/env bash
set -euo pipefail

# This skill script extracts the "Purpose" and execution dates of all plans
# in the .agent/plans directory (excluding README.md) and outputs them as a Plan Log.

readonly PLANS_DIR=".agent/plans"

extract_date() {
    local file="$1"
    local date_val
    
    date_val=$(awk 'tolower($0) ~ /^\**date completed:\**/ || tolower($0) ~ /^\**executed date:\**/ { sub(/^\**([Dd]ate [Cc]ompleted|[Ee]xecuted [Dd]ate):\**[ \t]*/, ""); print; exit }' "${file}")
    
    if [[ -z "${date_val}" ]]; then
        echo "Not specified"
    else
        echo "${date_val}"
    fi
}

extract_purpose() {
    local file="$1"
    local purpose_val
    
    purpose_val=$(awk 'tolower($0) ~ /^\**purpose:\**/ { sub(/^\**[Pp]urpose:\**[ \t]*/, ""); print; exit }' "${file}")
    
    if [[ -z "${purpose_val}" ]]; then
        echo "Not specified"
    else
        echo "${purpose_val}"
    fi
}

generate_plan_log() {
    echo "# Plan Log"
    echo ""
    
    # Iterate over markdown files in plans directory
    local has_plans=false
    
    for file in "${PLANS_DIR}"/*.md; do
        # Check if the file exists (in case glob doesn't match anything)
        if [[ -f "${file}" ]]; then
            local filename
            filename=$(basename "${file}")
            
            # Skip README.md
            if [[ "${filename}" == "README.md" ]]; then
                continue
            fi
            
            has_plans=true
            local plan_name="${filename%.md}"
            local date_val
            local purpose_val
            
            date_val=$(extract_date "${file}")
            purpose_val=$(extract_purpose "${file}")
            
            echo "## ${plan_name}"
            echo "- **Date:** ${date_val}"
            echo "- **Purpose:** ${purpose_val}"
            echo ""
        fi
    done
    
    if [[ "${has_plans}" == false ]]; then
        echo "No plans found in ${PLANS_DIR}."
    fi
}

main() {
    if [[ ! -d "${PLANS_DIR}" ]]; then
        echo "Error: Directory ${PLANS_DIR} does not exist." >&2
        exit 1
    fi
    
    generate_plan_log
}

main "$@"
