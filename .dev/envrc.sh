#!/usr/bin/env bash
#
# Helper: envrc.sh
# Description: Workstation entrypoint and direnv integration for the portable environment.

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DEV_DIR="${REPO_ROOT}/.dev"

nf() {
  nix --extra-experimental-features nix-command --extra-experimental-features flakes "$@"
}

get_repo_basename() {
  basename "$(git -C "${REPO_ROOT}" rev-parse --show-toplevel 2>/dev/null || echo "terraform-rancher2-aws")"
}

get_profile() {
  local bname
  bname="$(get_repo_basename)"
  echo "${HOME}/.config/nix/profiles/${bname}"
}

cleanup() {
  echo "Cleaning Up..."
  local profile
  profile="$(get_profile)"
  export NIX_PATH="${profile}"
  export NIX_PROFILE="${profile}"
  nix-env --profile "${profile}" --delete-generations +3 2>/dev/null || true
  nix-env --profile "${profile}" --list-generations 2>/dev/null || true
}

# Check if running inside container or inside an active nix develop shell
if [[ -n "${IN_CONTAINER:-}" || -n "${DEV_CONTAINER:-}" || -f "/.dockerenv" || -n "${IN_NIX_SHELL:-}" ]] || (command -v which >/dev/null 2>&1 && which "$0" 2>/dev/null | grep -q nix); then
  echo "Setting up dev environment..."
  if [[ -f "${DEV_DIR}/rc.sh" ]]; then
    # shellcheck source=/dev/null
    source "${DEV_DIR}/rc.sh"
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    install -d ~/.docker/cli-plugins/ 2>/dev/null || true
    ln -sfn "$(command -v docker-compose)" ~/.docker/cli-plugins/docker-compose 2>/dev/null || true
  fi
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi

# Direnv integration
if type use_flake >/dev/null 2>&1; then
  if [[ -f "${DEV_DIR}/rc.sh" ]]; then
    # shellcheck source=/dev/null
    source "${DEV_DIR}/rc.sh"
  fi
  use_flake "${DEV_DIR}#default"
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi

# Check for active container daemon (Docker/Podman)
CONTAINER_ACTIVE=false
if [[ "${DEV_NATIVE:-0}" != "1" && "${DEV_CONTAINER:-1}" == "1" ]]; then
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    CONTAINER_ACTIVE=true
  elif command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    CONTAINER_ACTIVE=true
  fi
fi

if [[ "${CONTAINER_ACTIVE}" == "true" ]]; then
  "${DEV_DIR}/container-run.sh" "$@"
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi

# Native Nix environment workflow
echo "Entering Environment..."
profile="$(get_profile)"
mkdir -p "$(dirname "${profile}")" 2>/dev/null || true
export NIX_PROFILE="${profile}"

echo "Adding Nix Profile..."
nf profile add "${DEV_DIR}" --profile "${profile}" 2>/dev/null || true
nf profile list --profile "${profile}" 2>/dev/null || true

echo "Starting..."
export IN_NIX_SHELL=1
nf develop "${DEV_DIR}#default" \
  --ignore-environment \
  --impure \
  --keep HOME \
  --keep TERM \
  --keep XDG_DATA_DIRS \
  --keep NIX_SSL_CERT_FILE \
  --keep NIX_PROFILE \
  --keep SSH_AUTH_SOCK \
  --keep SSH_SK_PROVIDER \
  --profile "${profile}" \
  --command bash -c "bash --rcfile '${DEV_DIR}/rc.sh'"

echo "Exiting Dev Environment..."
cleanup
