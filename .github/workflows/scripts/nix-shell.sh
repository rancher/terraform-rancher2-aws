#!/bin/bash
set -e

source /home/suse/.profile

nix develop
  --ignore-environment
  --extra-experimental-features nix-command
  --extra-experimental-features flakes
  --keep HOME
  --keep SSH_AUTH_SOCK
  --keep GITHUB_TOKEN
  --keep AWS_ROLE
  --keep AWS_REGION
  --keep AWS_DEFAULT_REGION
  --keep AWS_ACCESS_KEY_ID
  --keep AWS_SECRET_ACCESS_KEY
  --keep AWS_SESSION_TOKEN
  --keep UPDATECLI_GPGTOKEN
  --keep UPDATECLI_GITHUB_TOKEN
  --keep UPDATECLI_GITHUB_ACTOR
  --keep GPG_SIGNING_KEY
  --keep NIX_SSL_CERT_FILE
  --keep NIX_ENV_LOADED
  --keep TERM
  --command bash -e {0}
