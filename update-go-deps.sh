#!/bin/bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "Updating Go dependencies in the test module..."
cd "$REPO_ROOT/test"

go get -u ./...
go mod tidy

echo "Dependencies updated successfully."
