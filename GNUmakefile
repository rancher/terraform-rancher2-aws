default: fmt lint 

fmt:
	terraform fmt -recursive; \
	cd test; gofmt -s -w -e .; cd ..;

lint:
	tflint --recursive --fix; \
	cd test; \
	golangci-lint run -c "../.golangci.yml"; \
	cd ..; \
	actionlint;

test:
	./run_tests.sh -s

clean: # clean up test leftovers eg. `make clean -- i=<identifier>`
	./run_tests.sh -c $(i)

.PHONY: fmt lint test clean
