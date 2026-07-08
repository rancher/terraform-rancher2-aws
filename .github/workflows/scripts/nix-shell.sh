#!/bin/bash
set -e

source /home/suse/.profile

nix --version

nix develop \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes \
  --ignore-environment \
  --impure \
  --keep HOME \
  --keep SSH_AUTH_SOCK \
  --keep GITHUB_TOKEN \
  --keep AWS_ROLE \
  --keep AWS_REGION \
  --keep AWS_DEFAULT_REGION \
  --keep AWS_ACCESS_KEY_ID \
  --keep AWS_SECRET_ACCESS_KEY \
  --keep AWS_SESSION_TOKEN \
  --keep KUBE_CONFIG_PATH \
  --keep TERM \
  --keep XDG_DATA_DIRS \
  --keep NIX_SSL_CERT_FILE \
  --keep NIX_PROFILE \
  --command bash -c "{0}"
