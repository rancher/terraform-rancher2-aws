default: fmt lint 

fmt:
	terraform fmt -recursive; \
	cd test/tests; gofmt -s -w -e .; cd ../..

lint:
	tflint --recursive; \
	cd test/tests; golangci-lint run; cd ../..; \
	actionlint

test:
	./run_tests.sh -s

clean: # clean up test leftovers eg. `make clean -- i=<identifier>`
	./run_tests.sh -c $(i)

.PHONY: fmt lint test clean
