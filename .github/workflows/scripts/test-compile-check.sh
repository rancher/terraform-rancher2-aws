#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
TEST_DIR="test"

echo "Checking for compile errors in ${REPO_ROOT}/${TEST_DIR}..."

cd "${REPO_ROOT}/${TEST_DIR}" || exit 1

while IFS= read -r dir; do
  if [[ -n "${dir}" ]]; then
    echo "  compiling ${dir}..."
    if ! go test -c "${dir}" -o /dev/null 2>&1; then
      echo "ERROR: Failed to compile package in ${dir}"
      exit 1
    fi
  fi
done <<< "$(find . -path './data' -prune -o -type f -name '*.go' -exec dirname {} \; | sort -u)"
echo "✓ Compile checks passed"
