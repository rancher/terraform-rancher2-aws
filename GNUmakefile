SHELL := /bin/bash

default: fmt lint build install generate test testacc

fmt: fmt-go fmt-prettier

fmt-go:
	gofmt -s -w -e .

fmt-prettier:
	prettier --write .

lint: lint-scripts lint-format

lint-scripts:
	npx eslint .github/workflows/scripts/ .gemini/hooks/ .gemini/orchestrator/ .gemini/skills/

lint-format:
	prettier --check .

build:
	echo "nothing to build in this repo"

buildrace:
	echo "nothing to build in this repo"

testcompile:
	@if [ -d "./test" ] && [ -f "./test/go.mod" ]; then \
		(cd ./test && go test -run=^$$ ./...); \
	fi

compile: build testcompile

generate:
	cd tools; go generate ./...

dt: # run specific unit test
	gotestsum --format standard-verbose -- $(t)

test:
	gotestsum --format standard-verbose --jsonfile report.json --post-run-command "./test/summarize.sh" -- ./... -v -p=10 -timeout=300s -cover

unit:
	echo "no unit tests to run in this repo"

testacc:
	echo "no acc tests to run in this repo"

acc: testacc

test-scripts:
	node --test ".github/workflows/scripts/tests/**/*.test.js" ".gemini/orchestrator/lib/**/*.test.js" ".gemini/hooks/**/*.test.js" ".gemini/skills/**/tests/**/*.test.js"

test-all: test test-scripts

.PHONY: fmt lint lint-go lint-scripts lint-format build buildrace compile testcompile install generate test testacc testaccrelay debug unit acc test-scripts test-all
