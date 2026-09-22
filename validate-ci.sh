#!/usr/bin/env bash
set -euo pipefail

# CI Container image matching GitHub Actions workflows
CI_IMAGE="${CI_IMAGE:-ghcr.io/rancher/ci-image/nix:20260603-18}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

show_help() {
  cat <<'EOF'
Usage: validate-ci.sh [OPTIONS] [--] [COMMAND...]

Run arbitrary commands or scripts inside the CI testing environment.
By default, commands are executed inside the CI Docker container mirroring
GitHub Actions workflows.

Options:
  -l, --local        Run directly on host using 'nix develop .#ci' without Docker
  -i, --image IMAGE  Override CI Docker container image
                     (default: ghcr.io/rancher/ci-image/nix:20260603-18)
  -h, --help         Display this help message and exit

If no COMMAND is specified:
  - In an interactive terminal, launches an interactive bash shell.
  - In a non-interactive shell, defaults to './run_tests.sh --lint-only'.

Examples:
  ./validate-ci.sh
  ./validate-ci.sh --local
  ./validate-ci.sh ./run_tests.sh --lint-only
  ./validate-ci.sh -- bash .github/workflows/scripts/run-tests.sh -t TestDevBasic
  ./validate-ci.sh -l "terraform version && leftovers --version"
EOF
}

USE_LOCAL=false

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -l|--local)
      USE_LOCAL=true
      shift
      ;;
    -i|--image)
      if [ -z "${2:-}" ]; then
        echo "Error: $1 requires an image argument" >&2
        exit 1
      fi
      CI_IMAGE="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      echo "Use --help for usage information." >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

# Determine the command to execute
if [ $# -gt 0 ]; then
  # Properly quote arguments to preserve spaces and special characters
  CMD="$(printf '%q ' "$@")"
  CMD="${CMD% }"
elif [ -t 0 ]; then
  echo "No command specified. Starting interactive shell in CI environment..."
  CMD=""
else
  echo "No command specified and non-interactive. Running lint validation..."
  CMD="./run_tests.sh --lint-only"
fi

# If already running inside the CI container, invoke nix-run.sh directly
if [ -f "/home/suse/.nix-profile/bin/nix" ] || { [ -f "/.dockerenv" ] && [ -f "$REPO_ROOT/.github/workflows/scripts/nix-run.sh" ]; }; then
  cd "$REPO_ROOT"
  if [ -z "$CMD" ]; then
    exec bash "$REPO_ROOT/.github/workflows/scripts/nix-run.sh" "bash"
  else
    exec bash "$REPO_ROOT/.github/workflows/scripts/nix-run.sh" "$CMD"
  fi
fi

# If --local flag is passed or Docker is not running, run directly using the host's Nix
if [ "$USE_LOCAL" = true ] || ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  if [ "$USE_LOCAL" = false ]; then
    echo "Docker is not available or not running; falling back to local 'nix develop .#ci'..."
  fi

  cd "$REPO_ROOT"
  if [ -z "$CMD" ] && [ -t 0 ]; then
    exec nix develop .#ci \
      --extra-experimental-features nix-command \
      --extra-experimental-features flakes
  else
    exec nix develop .#ci \
      --extra-experimental-features nix-command \
      --extra-experimental-features flakes \
      --command bash -c "${CMD:-bash}"
  fi
fi

# Prepare Docker flags
DOCKER_ARGS=()
if [ -t 0 ] && [ -t 1 ]; then
  DOCKER_ARGS+=("-it")
fi

echo "Running in CI container ($CI_IMAGE): ${CMD:-bash}"

exec docker run --rm \
  ${DOCKER_ARGS[@]+"${DOCKER_ARGS[@]}"} \
  -v "$REPO_ROOT:$REPO_ROOT" \
  -w "$REPO_ROOT" \
  -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}" \
  -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}" \
  -e AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}" \
  -e AWS_ROLE="${AWS_ROLE:-}" \
  -e AWS_REGION="${AWS_REGION:-us-west-2}" \
  -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-west-2}" \
  -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
  -e GITHUB_OWNER="${GITHUB_OWNER:-rancher}" \
  -e ZONE="${ZONE:-}" \
  -e IDENTIFIER="${IDENTIFIER:-}" \
  -e ACME_SERVER_URL="${ACME_SERVER_URL:-https://acme-v02.api.letsencrypt.org/directory}" \
  -e CI="true" \
  "$CI_IMAGE" \
  bash "$REPO_ROOT/.github/workflows/scripts/nix-run.sh" "${CMD:-bash}"
