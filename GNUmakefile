default: fmt lint 

fmt:
	terraform fmt -recursive; \
	cd test; gofmt -s -w -e .; cd ../..

lint:
	tflint --recursive --fix; \
	cd test; golangci-lint run; cd ../..; \
  while IFS= read -r file; do \
    if ! go test -c "$$file" -o "$${file}.test"; then C=$$?; echo "failed to compile $$file, exit code $$C"; exit $$C; fi; \
    rm -f "$$file.test"; \
  done <<< "$$(find "./test" -not \( -path "./test/data" -prune \) -name '*.go')"; \
	actionlint

test:
	./run_tests.sh -s

clean: # clean up test leftovers eg. `make clean -- i=<identifier>`
	./run_tests.sh -c $(i)


.PHONY: fmt lint test clean
