#!/usr/bin/env bash
#
# Helper: nix-run.sh
# Description: Executes a command inside the development environment (delegating to container or native Nix).

set -euo pipefail

show_help() {
  cat <<EOF
Usage: $(basename "$0") [command] [args...]

Executes a command inside the development environment (container or native Nix).

Options:
  -h, --help    Show this help message and exit
EOF
}

setup_ssl() {
  if [[ -z "${NIX_SSL_CERT_FILE:-}" ]]; then
    for cert in /etc/ssl/cert.pem \
      "${HOME}/.nix-profile/etc/ssl/certs/ca-bundle.crt" \
      /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
      /etc/ssl/certs/ca-certificates.crt \
      /etc/ssl/certs/ca-bundle.crt \
      /etc/pki/tls/certs/ca-bundle.crt \
      /etc/ssl/ca-bundle.pem \
      /var/lib/ca-certificates/ca-bundle.pem; do
      if [[ -f "${cert}" ]]; then
        export NIX_SSL_CERT_FILE="${cert}"
        break
      fi
    done
  fi

  if [[ -n "${NIX_SSL_CERT_FILE:-}" ]]; then
    export SSL_CERT_FILE="${NIX_SSL_CERT_FILE}"
    export CURL_CA_BUNDLE="${NIX_SSL_CERT_FILE}"
    export NODE_EXTRA_CA_CERTS="${NODE_EXTRA_CA_CERTS:-${NIX_SSL_CERT_FILE}}"
  fi
}

main() {
  if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
  fi

  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
  local dev_dir="${repo_root}/.dev"

  # Skip nesting if already inside Nix shell or container
  if [[ -n "${IN_NIX_SHELL:-}" || -n "${IN_CONTAINER:-}" || -n "${DEV_CONTAINER:-}" ]]; then
    exec "$@"
  fi

  # Prefer container execution if runtime is active and not forced to native
  local container_active=false
  if [[ "${DEV_NATIVE:-0}" != "1" && "${DEV_CONTAINER:-1}" == "1" ]]; then
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      container_active=true
    elif command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
      container_active=true
    fi
  fi

  if [[ "${container_active}" == "true" && -x "${dev_dir}/container-run.sh" ]]; then
    exec "${dev_dir}/container-run.sh" "$@"
  fi

  # Native Nix develop execution
  export PATH="${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"
  setup_ssl

  if ! command -v nix >/dev/null 2>&1; then
    echo "Error: Neither a running container daemon nor 'nix' binary was found." >&2
    exit 1
  fi

  export IN_NIX_SHELL=1
  exec nix develop "${dev_dir}#default" \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    --command bash -c 'if [[ -f "'"${dev_dir}"'/rc.sh" ]]; then source "'"${dev_dir}"'/rc.sh"; fi; exec "$@"' -- "$@"
}

main "$@"
