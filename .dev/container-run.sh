#!/usr/bin/env bash
#
# Helper: container-run.sh
# Description: Launches the isolated development container matching the CI environment.

set -euo pipefail

CI_IMAGE="${DEV_CONTAINER_IMAGE:-ghcr.io/rancher/ci-image/nix:20260603-18}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

# Verify container runtime daemon is reachable
CONTAINER_RUNTIME=""
for runtime in docker podman; do
  if command -v "${runtime}" >/dev/null 2>&1 && "${runtime}" info >/dev/null 2>&1; then
    CONTAINER_RUNTIME="${runtime}"
    break
  fi
done

if [[ -z "${CONTAINER_RUNTIME}" ]]; then
  echo "Error: Neither docker nor podman daemon is running and reachable." >&2
  exit 1
fi

ENV_ARGS=()
for var in \
  GITHUB_TOKEN \
  GH_TOKEN \
  GEMINI_API_KEY \
  ANTHROPIC_API_KEY \
  TF_IN_AUTOMATION; do
  if [[ -n "${!var:-}" ]]; then
    ENV_ARGS+=("-e" "${var}")
  fi
done

SSH_ARGS=()
if [[ -n "${SSH_AUTH_SOCK:-}" && -S "${SSH_AUTH_SOCK}" ]]; then
  SSH_ARGS+=("-v" "${SSH_AUTH_SOCK}:/tmp/ssh-agent.sock" "-e" "SSH_AUTH_SOCK=/tmp/ssh-agent.sock")
fi

echo "Launching isolated development container (${CI_IMAGE})..." >&2

if [[ $# -gt 0 ]]; then
  exec "${CONTAINER_RUNTIME}" run --rm -i \
    -v "${REPO_ROOT}:/workspace" \
    -w "/workspace" \
    -e "IN_CONTAINER=1" \
    -e "DEV_CONTAINER=1" \
    "${ENV_ARGS[@]}" \
    "${SSH_ARGS[@]}" \
    "${CI_IMAGE}" \
    nix develop /workspace/.dev#default --command bash -c 'if [[ -f "/workspace/.dev/rc.sh" ]]; then source "/workspace/.dev/rc.sh"; fi; exec "$@"' -- "$@"
else
  exec "${CONTAINER_RUNTIME}" run --rm -it \
    -v "${REPO_ROOT}:/workspace" \
    -w "/workspace" \
    -e "IN_CONTAINER=1" \
    -e "DEV_CONTAINER=1" \
    "${ENV_ARGS[@]}" \
    "${SSH_ARGS[@]}" \
    "${CI_IMAGE}" \
    nix develop /workspace/.dev#default --command bash --rcfile /workspace/.dev/rc.sh
fi
