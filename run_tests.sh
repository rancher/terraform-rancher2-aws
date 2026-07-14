#!/bin/bash
set -e

# Configuration flags
rerun_failed=false
specific_test=""
specific_package=""
specific_fixture=""
fixture_group=""
cleanup_id=""
wait_time=""
slow_mode=false
dirty_mode=false
speed_mode="6"
build_only=false
lint_only=false

# Track whether cleanup has run
cleanup_has_run=false

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TEST_DIR=""

# Cleanup function that will be called on exit
run_cleanup() {
  # Avoid running cleanup twice
  if [ "$cleanup_has_run" = true ]; then
    return 0
  fi
  cleanup_has_run=true

  # Skip if dirty mode or no identifier
  if [ "$dirty_mode" = true ] || [ -z "$IDENTIFIER" ]; then
    return 0
  fi

  echo ""
  echo "=== Cleanup ==="

  # Wait before cleanup if requested (for investigation)
  if [ -n "$WAIT" ] && [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ]; then
    echo "Tests failed. Waiting $WAIT seconds before cleanup for investigation..."
    sleep "$WAIT"
  fi

  # Check if cleanup script exists
  if [ -f "$REPO_ROOT/cleanup.sh" ]; then
    echo "Running cleanup script..."
    sh "$REPO_ROOT/cleanup.sh" "$IDENTIFIER"
    cleanup_exit=$?

    if [ $cleanup_exit -ne 0 ]; then
      echo "WARNING: Cleanup failed with exit code $cleanup_exit"
    else
      echo "✓ Cleanup completed successfully"
    fi
  else
    echo "WARNING: cleanup.sh not found, skipping automated cleanup"
    echo "You may need to manually clean up resources with ID: $IDENTIFIER"
  fi
}

parse_options() {
  local OPTIND=1
  # Parse command line options
  while getopts ":rsdt:p:f:g:c:w:n:-:" opt; do
    case $opt in
      r) rerun_failed=true ;;
      t) specific_test="$OPTARG" ;;
      p) specific_package="$OPTARG" ;;
      f) specific_fixture="$OPTARG" ;;
      g) fixture_group="$OPTARG" ;;
      c) cleanup_id="$OPTARG" ;;
      w) wait_time="$OPTARG" ;;
      d) dirty_mode=true ;;
      n) speed_mode="$OPTARG" ;;
      s) slow_mode=true ;;
      -)
        case "${OPTARG}" in
          build-only) build_only=true ;;
          lint-only) lint_only=true ;;
          *) echo "Invalid option: --${OPTARG}" >&2; exit 1 ;;
        esac
        ;;
      \?) cat <<EOT >&2 && exit 1
Invalid option: -$OPTARG

Usage: $0 [OPTIONS]

Options:
  -r              Re-run failed tests
  -s              Run tests in slow mode (sequential, one at a time)
  -d              Skip cleanup (dirty mode)
  -t TEST         Run specific test (eg. TestMatrix)
  -p PACKAGE      Run specific test package (eg. one)
  -f FIXTURE      Run specific fixture combination (eg. "sle-micro-61-canal-stable-one-rpm-ipv4")
  -g GROUP        Run specific fixture group (eg. "necessary" or "extended")
  -c ID           Cleanup-only mode with the given identifier
  -w SECONDS      Wait time in seconds before cleanup on test failure (for investigation)
  -n SPEED        Set the number of consecutive tests and test packages (speed)
  --build-only    Build up the global plugin cache and validate examples, then exit
  --lint-only     Run the lint action and then exit

Notes:
  - Only one of -c, -t, -p, -f, -g, --build-only, or --lint-only can be used at a time
  - The -f option sets the COMBO environment variable for fixture selection
  - The -g option sets the GROUP environment variable for fixture group selection
  - The -w option sets the WAIT environment variable for error investigation
EOT
    esac
  done
}

validate_options() {
  # Validate mutually exclusive options
  local exclusive_count=0
  [ -n "$cleanup_id" ] && ((exclusive_count++))
  [ -n "$specific_test" ] && ((exclusive_count++))
  [ -n "$specific_package" ] && ((exclusive_count++))
  [ -n "$specific_fixture" ] && ((exclusive_count++))
  [ -n "$fixture_group" ] && ((exclusive_count++))
  [ "$build_only" = true ] && ((exclusive_count++))
  [ "$lint_only" = true ] && ((exclusive_count++))

  if [ $exclusive_count -gt 1 ]; then
    echo "Error: Only one of -c, -t, -p, -f, -g, --build-only, or --lint-only can be used at a time." >&2
    exit 1
  fi
}

display_configuration() {
  # Display configuration
  echo "=== Test Configuration ==="
  if [ "$slow_mode" = true ]; then
    echo "Mode: Slow (sequential execution to avoid AWS rate limiting)"
  elif [ -n "$speed_mode" ]; then
    echo "Mode: Custom speed ($speed_mode parallel execution)"
  else
    echo "Mode: Normal (parallel execution)"
  fi

  if [ "$rerun_failed" = true ]; then
    echo "Rerun failed tests: Enabled"
  fi

  if [ "$dirty_mode" = true ]; then
    echo "Cleanup: Disabled (dirty mode)"
  else
    echo "Cleanup: Enabled"
  fi

  if [ -n "$specific_test" ]; then
    echo "Specific test: $specific_test"
  fi

  if [ -n "$specific_package" ]; then
    echo "Specific package: $specific_package"
  fi

  if [ -n "$specific_fixture" ]; then
    echo "Specific fixture: $specific_fixture"
  fi

  if [ -n "$fixture_group" ]; then
    echo "Fixture group: $fixture_group"
  fi

  if [ -n "$cleanup_id" ]; then
    echo "Cleanup-only mode: $cleanup_id"
  fi

  if [ -n "$wait_time" ]; then
    echo "Wait time on failure: $wait_time seconds"
  fi

  if [ "$build_only" = true ]; then
    echo "Build-only mode: Enabled"
  fi

  if [ "$lint_only" = true ]; then
    echo "Lint-only mode: Enabled"
  fi

  echo "=========================="
  echo ""
}

setup_environment() {
  # Set cleanup ID if provided
  if [ -n "$cleanup_id" ]; then
    export IDENTIFIER="$cleanup_id"
  fi

  # Set COMBO environment variable for fixture selection
  export COMBO="$specific_fixture"
  if [ -n "$COMBO" ]; then
    echo "COMBO environment variable set to: $COMBO"
  fi

  # Set GROUP environment variable for fixture group selection
  export GROUP="$fixture_group"
  if [ -n "$GROUP" ]; then
    echo "GROUP environment variable set to: $GROUP"
  fi

  # Set WAIT environment variable for error investigation
  export WAIT="$wait_time"
  if [ -n "$WAIT" ]; then
    echo "WAIT environment variable set to: $WAIT seconds"
  fi

  # Locate repository root
  REPO_ROOT="$(git rev-parse --show-toplevel)"

  # Generate and export identifier
  if [ -z "$IDENTIFIER" ]; then
    IDENTIFIER="$(echo "a-$RANDOM-d" | base64 | tr -d '=')"
    export IDENTIFIER
  fi

  echo "Test identifier: $IDENTIFIER"
  echo ""
}

# Find the tests directory
find_test_dir() {
  local test_dir=""
  if [ -d "$REPO_ROOT/test/tests" ]; then
    test_dir="test/tests"
  elif [ -d "$REPO_ROOT/tests" ]; then
    test_dir="tests"
  elif [ -d "$REPO_ROOT/test" ]; then
    test_dir="test"
  else
    echo "Error: Unable to find tests directory" >&2
    exit 1
  fi
  echo "$test_dir"
}

setup_test_processor() {
  echo "" > "/tmp/${IDENTIFIER}_test.log"

  cat <<'EOF' > "/tmp/${IDENTIFIER}_test-processor"
echo "Passed: "
export PASS="$(jq -r '. | select(.Action == "pass") | select(.Test != null).Test' "/tmp/${IDENTIFIER}_test.log")"
echo "$PASS" | tr ' ' '\n'
echo " "
echo "Failed: "
export FAIL="$(jq -r '. | select(.Action == "fail") | select(.Test != null).Test' "/tmp/${IDENTIFIER}_test.log")"
echo "$FAIL" | tr ' ' '\n'
echo " "
if [ -n "$FAIL" ]; then
  echo "$FAIL" > "/tmp/${IDENTIFIER}_failed_tests.txt"
  exit 1
fi
exit 0
EOF
  chmod +x "/tmp/${IDENTIFIER}_test-processor"
}

execute_gotestsum() {
  local package_pattern="$1"
  local parallel_packages="$2"
  local parallel_tests="$3"
  local rerun_flag="$4"
  local specific_test_flag="$5"

  # Display the command that will be run
  echo ""
  echo "Test command:"
  echo "  gotestsum --format=standard-verbose \\"
  echo "    --jsonfile /tmp/${IDENTIFIER}_test.log \\"
  echo "    --post-run-command 'sh /tmp/${IDENTIFIER}_test-processor' \\"
  echo "    --packages $REPO_ROOT/$TEST_DIR/$package_pattern \\"
  echo "    -- -count=1 -timeout=300m -failfast \\"
  echo "      $parallel_packages $parallel_tests \\"
  echo "      $rerun_flag $specific_test_flag"
  echo ""

  # Run tests
  # shellcheck disable=SC2086
  gotestsum \
    --format=standard-verbose \
    --jsonfile "/tmp/${IDENTIFIER}_test.log" \
    --post-run-command "sh /tmp/${IDENTIFIER}_test-processor" \
    --packages "$REPO_ROOT/$TEST_DIR/$package_pattern" \
    -- \
    -count=1 \
    -timeout=300m \
    -failfast \
    $parallel_packages \
    $parallel_tests \
    $rerun_flag \
    $specific_test_flag
}

# Run tests function
run_tests() {
  local rerun=$1
  local slow_mode=$2

  setup_test_processor

  export NO_COLOR=1
  echo "Starting tests..."
  cd "$REPO_ROOT/$TEST_DIR" || exit 1

  # Build rerun flag
  local rerun_flag=""
  if [ "$rerun" = true ] && [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ]; then
    rerun_flag="-run=$(tr '\n' '|' < "/tmp/${IDENTIFIER}_failed_tests.txt" | sed 's/|$//')"
    echo "Rerunning failed tests: $rerun_flag"
  fi

  # Build specific test flag
  local specific_test_flag=""
  if [ -n "$specific_test" ] && [ "$rerun" != true ]; then
    specific_test_flag="-run=$specific_test"
    echo "Running specific test: $specific_test"
  fi

  # Build package pattern
  local package_pattern=""
  if [ -n "$specific_package" ]; then
    package_pattern="$specific_package"
    echo "Running specific package: $specific_package"
  else
    package_pattern="..."
  fi

  # Build parallel flags for slow mode
  local parallel_packages=""
  local parallel_tests=""
  if [ "$slow_mode" = true ]; then
    echo "Slow mode: Running tests sequentially"
    parallel_packages="-p=1"
    parallel_tests="-parallel=1"
  elif [ -n "$speed_mode" ]; then
    echo "Custom speed: Running $speed_mode tests in parallel"
    parallel_packages="-p=$speed_mode"
    parallel_tests="-parallel=$speed_mode"
  fi

  execute_gotestsum "$package_pattern" "$parallel_packages" "$parallel_tests" "$rerun_flag" "$specific_test_flag"

  return $?
}

check_environment() {
  # Check required environment variables
  echo "=== Environment Check ==="
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "WARNING: GITHUB_TOKEN is not set"
  else
    echo "GITHUB_TOKEN: Set"
  fi

  if [ -z "$GITHUB_OWNER" ]; then
    echo "WARNING: GITHUB_OWNER is not set"
  else
    echo "GITHUB_OWNER: Set ($GITHUB_OWNER)"
  fi

  if [ -z "$ZONE" ]; then
    echo "WARNING: ZONE is not set"
  else
    echo "ZONE: Set"
  fi
  echo "========================="
  echo ""
}

pre_test_validation() {
  # Pre-test validation
  local current_dir
  current_dir="$(pwd)"

  echo "=== Pre-Test Validation ==="

  echo "Running go mod tidy..."
  cd "$REPO_ROOT/$TEST_DIR" || exit 1
  if ! go mod tidy; then
    echo "ERROR: go mod tidy failed"
    exit 1
  fi
  echo "✓ go mod tidy passed"

  echo "Formatting tests..."
  gofmt -s -w -e .
  echo "✓ Formatting complete"

  echo "Checking for compile errors..."
  while IFS= read -r dir; do
    if [ -n "$dir" ]; then
      echo "  compiling ${dir}..."
      if ! go test -c "$dir" -o /dev/null 2>&1; then
        echo "ERROR: Failed to compile package in $dir"
        exit 1
      fi
    fi
  done <<< "$(find . -path './data' -prune -o -type f -name '*.go' -exec dirname {} \; | sort -u)"
  echo "✓ Compile checks passed"

  echo "Running go lint..."
  if ! golangci-lint run -c "$REPO_ROOT/.golangci.yml"; then
    echo "ERROR: Linting failed"
    exit 1
  fi
  echo "✓ Lint passed"

  cd "$current_dir" || exit 1

  echo "Checking terraform configs..."
  if ! tflint --recursive; then
    echo "ERROR: tflint failed"
    exit 1
  fi
  echo "✓ Terraform configs valid"

  echo "Running actionlint..."
  if ! actionlint; then
    echo "ERROR: actionlint failed"
    exit 1
  fi
  echo "✓ actionlint passed"

  echo "Running shellcheck..."
  if ! find . -name "*.sh" -not -path "./.terraform/*" -exec shellcheck {} +; then
    echo "ERROR: shellcheck failed"
    exit 1
  fi
  echo "✓ shellcheck passed"

  echo "Running npm install..."
  if [ -f "package.json" ]; then
    npm install --no-fund --no-audit || echo "WARNING: npm install failed, eslint may fail"
  else
    # Install required eslint packages directly if package.json is missing
    npm install --no-save @eslint/js globals eslint || echo "WARNING: npm install failed, eslint may fail"
  fi

  echo "Running eslint..."
  if ! eslint .; then
    echo "ERROR: eslint failed"
    exit 1
  fi
  echo "✓ eslint passed"

  echo "============================"
  echo ""

}

execute_tests() {
  # Clear failed tests before initial run
  rm -f "/tmp/${IDENTIFIER}_failed_tests.txt"

  # Run tests initially
  echo "=== Running Tests ==="
  run_tests false "$slow_mode"
  test_exit_code=$?

  if [ $test_exit_code -ne 0 ]; then
    echo "Tests failed with exit code: $test_exit_code"
  else
    echo "Tests passed"
  fi

  # Brief pause between test runs
  sleep 5

  # Check if we need to rerun failed tests
  if [ "$rerun_failed" = true ] && [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ]; then
    echo ""
    echo "=== Rerunning Failed Tests ==="
    run_tests true "$slow_mode"
    test_exit_code=$?

    if [ $test_exit_code -ne 0 ]; then
      echo "Rerun failed with exit code: $test_exit_code"
    else
      echo "All tests passed on rerun"
    fi

    sleep 5
  fi
}

display_summary() {
  echo ""
  echo "=== Test Summary ==="

  # Exit with appropriate code based on test results
  if [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ]; then
    echo "Tests FAILED"
    echo "Failed tests logged to: /tmp/${IDENTIFIER}_failed_tests.txt"
    exit 1
  else
    echo "All tests PASSED"
    exit 0
  fi
}

prime_plugin_cache() {
  echo "=== Prime Plugin Cache ==="
  echo "priming terraform plugin cache..."
  export GLOBAL_TF_PLUGIN_CACHE="$HOME/.terraform.d/plugin-cache"
  mkdir -p "$GLOBAL_TF_PLUGIN_CACHE"
  export TF_PLUGIN_CACHE_DIR="$GLOBAL_TF_PLUGIN_CACHE"
  while IFS= read -r dir; do
    pushd "$dir" || exit

    needs_mirror=false

    (terraform get > /dev/null 2>&1 || true)
    providers=$(terraform providers | grep provider | awk -F'provider' '{print $2}' | awk -F'[' '{print $2}' | awk -F']' '{print $1}' | sort | uniq || true)

    for p in $providers; do
      if [ "$p" = "terraform.io/builtin/terraform" ]; then
        continue
      fi
      if [ ! -d "$GLOBAL_TF_PLUGIN_CACHE/$p" ]; then
        echo "Global cache doesn't have provider: $p"
        needs_mirror=true
        break
      fi
    done

    if $needs_mirror; then
      echo "  running 'terraform providers mirror $GLOBAL_TF_PLUGIN_CACHE' in $dir..."
      (terraform providers mirror "$GLOBAL_TF_PLUGIN_CACHE" > /dev/null 2>&1 || true)
    fi
    rm -rf .terraform

    popd || exit
  done <<< "$(find "$REPO_ROOT/examples" -name 'main.tf' -not -path '*/.terraform/*' -exec dirname {} \; | sort -u)"
  unset TF_PLUGIN_CACHE_DIR
}

validate_examples() {
  echo "=== Validate Examples ==="
  export GLOBAL_TF_PLUGIN_CACHE="$HOME/.terraform.d/plugin-cache"
  export TF_PLUGIN_CACHE_DIR="$GLOBAL_TF_PLUGIN_CACHE"

  while IFS= read -r dir; do
    pushd "$dir" > /dev/null || exit 1
    echo "  validating example in $dir..."

    (terraform init -backend=false > /dev/null 2>&1 || true)
    if ! terraform validate; then
      echo "ERROR: Terraform validation failed in $dir"
      popd > /dev/null || exit 1
      exit 1
    fi
    rm -rf .terraform
    rm -f .terraform.lock.hcl
    popd > /dev/null || exit 1
  done <<< "$(find "$REPO_ROOT/examples" -name 'main.tf' -not -path '*/.terraform/*' -exec dirname {} \; | sort -u)"
  echo "✓ All examples validated successfully"
  echo ""
}

main() {
  parse_options "$@"
  validate_options

  # Set trap to run cleanup on exit, error, interrupt, or termination
  trap run_cleanup EXIT ERR INT TERM

  display_configuration

  if [ "$lint_only" = true ]; then
    echo "Lint-only mode enabled, skipping tests and cleanup..."
    TEST_DIR="$(find_test_dir)"
    dirty_mode=true # Skip cleanup
    pre_test_validation
    validate_examples
    echo "Lint-only mode completed successfully"
    exit 0
  fi

  if [ "$build_only" = true ]; then
    echo "Build-only mode enabled, skipping tests and cleanup..."
    dirty_mode=true # Skip cleanup
    prime_plugin_cache
    echo "Build-only mode completed successfully"
    exit 0
  fi

  prime_plugin_cache
  setup_environment

  TEST_DIR="$(find_test_dir)"
  echo "Using test directory: $TEST_DIR"
  echo ""

  check_environment

  # If cleanup-only mode, skip tests and run cleanup directly
  if [ -n "$cleanup_id" ]; then
    echo "Cleanup-only mode enabled, skipping tests..."
    # In cleanup-only mode, we want to run cleanup immediately
    run_cleanup
    echo "Cleanup-only mode completed"
    exit 0
  fi

  pre_test_validation
  execute_tests
  display_summary
}

main "$@"
