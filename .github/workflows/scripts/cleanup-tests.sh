#!/usr/bin/env bash
set -euo pipefail

export AWS_MAX_ATTEMPTS="100"
./run_tests.sh -c "${IDENTIFIER}"
