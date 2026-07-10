#!/bin/bash
set -e

cd test/tests
echo "checking tests for go lint errors..."
if ! golangci-lint run; then echo "lint failed..."; exit 1; fi
echo "lint errors complete"
echo "checking for format issues"
if [ -n "$(gofmt -l -s -d .)" ]; then echo "some files need formatting..."; exit 1; fi
echo "formatting check complete"
