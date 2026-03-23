SHELL := /usr/bin/env bash

.PHONY: lint test build verify

lint:
	bash scripts/lint.sh

test:
	bash scripts/test.sh

build:
	bash scripts/build-release.sh

verify:
	bash scripts/verify.sh
