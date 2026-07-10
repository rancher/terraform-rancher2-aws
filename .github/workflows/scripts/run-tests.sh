#!/usr/bin/env bash
set -euo pipefail

export AWS_MAX_ATTEMPTS="100"
export AWS_RETRY_MODE="adaptive"
export GITHUB_OWNER="rancher"
export ACME_SERVER_URL="https://acme-v02.api.letsencrypt.org/directory"
export RANCHER_INSECURE="false"

./run_tests.sh -s
