#!/usr/bin/env bash
#
# Helper: lint.sh
# Description: Unified static analysis and formatting verification harness.
# Conforms to shell-scripts.instructions.md guidelines.

set -euo pipefail

show_help() {
  cat <<EOF
Usage: lint.sh [mode]

Harness to run static analysis and code formatting verification.

Modes:
  terraform       Lint Terraform configurations.
  actionlint      Lint GitHub Actions workflow files.
  eslint          Lint JavaScript/MJS codebase files.
  shellcheck      Lint shell script code.
  tests           Run Go test-specific linters.
  gitleaks        Scan repository for hardcoded secrets.
  shfmt           Verify shell script code formatting.
  prettier        Verify formatting of JS, JSON, and MD files.
  markdownlint    Validate Markdown semantic structure.
  golangci-lint   Check Go source code against static analysis rules.
  cspell          Verify spelling across codebase files.
  all             Execute all above verification suites (default).

Options:
  -h, --help      Show this help message and exit.
  -f, --fix       Auto-format code where supported (Prettier, shfmt, gofmt).
EOF
}

run_terraform() {
  echo "==> Linting Terraform files..."
  terraform fmt -check -recursive
  tflint --recursive
}

run_actionlint() {
  echo "==> Linting GitHub workflows..."
  actionlint -ignore 'unknown permission scope "copilot-requests"'
}

run_eslint() {
  echo "==> Running eslint check on scripts..."
  if [[ ! -d "node_modules" && -f "package.json" ]]; then
    echo "==> Installing local eslint dependencies..."
    if ! npm ci --no-audit --no-fund --silent && ! npm install --no-audit --no-fund --silent; then
      echo "Error: Failed to install ESLint node dependencies (npm ci and npm install both failed)." >&2
      exit 1
    fi
  fi

  local lint_dirs=(".github/workflows/scripts/" ".gemini/hooks/" "agent-scripts/")
  local dir
  for dir in "${lint_dirs[@]}"; do
    if [[ -d "${dir}" ]]; then
      npx eslint "${dir}"
    fi
  done

  echo "==> Auditing catch statements..."
  if [[ -f ".github/workflows/scripts/check-catch.js" ]]; then
    node .github/workflows/scripts/check-catch.js
  fi
}

run_shellcheck() {
  echo "==> Running shellcheck..."
  local files
  files=$( (
    find . -type f -name "*.sh"
    grep -Rl -E '^#![[:space:]]*.*(/bash|/sh|[[:space:]]bash|[[:space:]]sh)([[:space:]]|$)' .
  ) 2>/dev/null \
    | grep -v -E "^\./(\.git|\.terraform|bin)/" \
    | grep -v -E "\.(md|js|mjs)$" \
    | sort -u || true)

  if [[ -z "${files}" ]]; then
    echo "No shell scripts found to check."
    return 0
  fi

  while read -r file; do
    if [[ -f "${file}" ]]; then
      echo "Checking ${file}..."
      shellcheck -x "${file}"
    fi
  done <<<"${files}"
}

run_shfmt() {
  local fix_mode="${1:-false}"
  if [[ "${fix_mode}" == "true" ]]; then
    echo "==> Auto-formatting shell scripts with shfmt..."
  else
    echo "==> Verifying shell script formatting with shfmt..."
  fi

  local files
  files=$(grep -Rl -e '^#!' . \
    | grep -v -E "^\./(\.git|\.terraform|\.gemini|bin|agent-scripts)/" \
    | grep -v -E "\.(md|js|mjs)$" || true)

  if [[ -z "${files}" ]]; then
    echo "No shell scripts found to process."
    return 0
  fi

  if [[ "${fix_mode}" == "true" ]]; then
    # shellcheck disable=SC2086
    shfmt -i 2 -ci -bn -w ${files}
  else
    # shellcheck disable=SC2086
    shfmt -i 2 -ci -bn -d ${files}
  fi
}

run_prettier() {
  local fix_mode="${1:-false}"
  if [[ "${fix_mode}" == "true" ]]; then
    echo "==> Auto-formatting files with prettier..."
    prettier --write .
  else
    echo "==> Verifying formatting with prettier..."
    prettier --check .
  fi
}

run_markdownlint() {
  echo "==> Validating markdown files with markdownlint..."
  markdownlint . --ignore-path .gitignore -i CHANGELOG.md
}

run_golangci_lint() {
  local fix_mode="${1:-false}"
  local fix_flag=""
  if [[ "${fix_mode}" == "true" ]]; then
    fix_flag="--fix"
  fi

  echo "==> Running golangci-lint on Go code..."
  if [[ ! -f "go.mod" ]]; then
    echo "No go.mod found in root, skipping root golangci-lint."
  else
    echo "--> Linting root module..."
    # shellcheck disable=SC2086
    golangci-lint run --timeout=5m ${fix_flag}
  fi

  if [[ -d "test" ]]; then
    if [[ -f "test/go.mod" ]]; then
      echo "--> Linting test module..."
      # shellcheck disable=SC2086
      (cd test && golangci-lint run --timeout=5m ${fix_flag})
    else
      echo "No go.mod found in 'test' directory, skipping test module golangci-lint."
    fi
  fi
}

run_tests_lint() {
  echo "==> Linting Go test files (legacy check)..."
  if [[ ! -d "test" ]]; then
    echo "No 'test' directory found, skipping legacy test lint."
    return 0
  fi
  if [[ ! -f "test/go.mod" ]]; then
    echo "No go.mod found in 'test' directory, skipping legacy test lint."
    return 0
  fi
  cd test
  if ! golangci-lint run; then
    echo "Error: golangci-lint failed on tests..." >&2
    exit 1
  fi
  if [[ -n "$(gofmt -l -s -d .)" ]]; then
    echo "Error: Go test files need formatting..." >&2
    exit 1
  fi
  cd ..
}

run_gitleaks() {
  echo "==> Scanning for secrets with gitleaks..."
  gitleaks detect --no-banner -v --no-git
  gitleaks detect --no-banner -v
}

run_cspell() {
  echo "==> Running spelling checks with cspell..."
  cspell lint --no-progress "**/*"
}

parse_args() {
  MODE="all"
  FIX_MODE="false"

  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
      -h | --help)
        show_help
        exit 0
        ;;
      -f | --fix)
        FIX_MODE="true"
        shift
        ;;
      *)
        MODE="${1}"
        shift
        ;;
    esac
  done
}

main() {
  parse_args "${@}"

  # Defensive check: if Go files exist but no go.mod is present anywhere, fail early to prevent silent skipped tests
  local go_files
  go_files=$(git ls-files "*.go" 2>/dev/null | head -n 1)
  local go_mods
  go_mods=$(find . -name "go.mod" -not -path "*/.terraform/*" | head -n 1)
  if [[ -n "${go_files}" && -z "${go_mods}" ]]; then
    echo "Error: Go source files were found, but no go.mod is present!" >&2
    exit 1
  fi

  case "${MODE}" in
    terraform)
      run_terraform
      ;;
    actionlint)
      run_actionlint
      ;;
    eslint)
      run_eslint
      ;;
    shellcheck)
      run_shellcheck
      ;;
    shfmt)
      run_shfmt "${FIX_MODE}"
      ;;
    prettier)
      run_prettier "${FIX_MODE}"
      ;;
    markdownlint)
      run_markdownlint
      ;;
    golangci-lint)
      run_golangci_lint "${FIX_MODE}"
      ;;
    tests)
      run_tests_lint
      ;;
    gitleaks)
      run_gitleaks
      ;;
    cspell)
      run_cspell
      ;;
    all)
      run_terraform
      run_actionlint
      run_eslint
      run_shellcheck
      run_shfmt "${FIX_MODE}"
      run_prettier "${FIX_MODE}"
      run_markdownlint
      run_golangci_lint "${FIX_MODE}"
      run_gitleaks
      run_cspell
      ;;
    *)
      echo "Error: Unknown lint mode: ${MODE}" >&2
      echo "Usage: ${0} [terraform|actionlint|eslint|shellcheck|shfmt|prettier|markdownlint|golangci-lint|tests|gitleaks|cspell|all] [-f|--fix]" >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
