# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2023-Present The UDS Authors

ARCH ?= amd64
CLI_VERSION ?= $(if $(shell git describe --tags),$(shell git describe --tags),"UnknownVersion")
K9S_VERSION=$(shell go list -f '{{.Version}}' -m github.com/derailed/k9s)
CRANE_VERSION=$(shell go list -f '{{.Version}}' -m github.com/google/go-containerregistry)
SYFT_VERSION=$(shell go list -f '{{.Version}}' -m github.com/anchore/syft)
ARCHIVER_VERSION=$(shell go list -f '{{.Version}}' -m github.com/mholt/archiver/v3)
HELM_VERSION=$(shell go list -f '{{.Version}}' -m helm.sh/helm/v3)
BUILD_ARGS := -s -w -X 'github.com/defenseunicorns/uds-cli/src/config.CLIVersion=$(CLI_VERSION)' \
				    -X 'github.com/defenseunicorns/zarf/src/config.ActionsCommandZarfPrefix=zarf' \
					-X 'github.com/derailed/k9s/cmd.version=$(K9S_VERSION)' \
					-X 'github.com/google/go-containerregistry/cmd/crane/cmd.Version=$(CRANE_VERSION)' \
					-X 'github.com/defenseunicorns/zarf/src/cmd/tools.syftVersion=$(SYFT_VERSION)' \
					-X 'github.com/defenseunicorns/zarf/src/cmd/tools.archiverVersion=$(ARCHIVER_VERSION)' \
					-X 'github.com/defenseunicorns/zarf/src/cmd/tools.helmVersion=$(HELM_VERSION)'

.PHONY: help
help: ## Display this help information
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | sort | awk 'BEGIN {FS = ":.*?## "}; \
	  {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build-cli-linux-amd: ## Build the CLI for Linux AMD64
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(BUILD_ARGS)" -o build/uds main.go

build-cli-linux-arm: ## Build the CLI for Linux ARM64
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="$(BUILD_ARGS)" -o build/uds-arm main.go

build-cli-mac-intel: ## Build the CLI for Mac Intel
	GOOS=darwin GOARCH=amd64 go build -ldflags="$(BUILD_ARGS)" -o build/uds-mac-intel main.go

build-cli-mac-apple: ## Build the CLI for Mac Apple
	GOOS=darwin GOARCH=arm64 go build -ldflags="$(BUILD_ARGS)" -o build/uds-mac-apple main.go

test-unit: ## Run Unit Tests
	cd src/pkg && go test ./... -failfast -v -timeout 5m

test-e2e: ## Run End to End (e2e) tests
	cd src/test/e2e && go test -failfast -v -timeout 30m

test-e2e-ghcr: ## Run End to End (e2e) tests with GHCR (contains writes)
	cd src/test/e2e && go test -failfast -v -timeout 30m -run ".*GHCR.*"

test-e2e-no-ghcr-write: ## Run End to End (e2e) tests without GHCR
	cd src/test/e2e && go test -failfast -v -timeout 30m -skip ".*GHCR.*"

test-e2e-runner: ## Run End to End (e2e) tests for task runner only
	cd src/test/e2e && go test -failfast -v -timeout 30m -run TestTaskRunner

schema: ## Update JSON schema for uds-bundle.yaml
	./hack/generate-schema.sh

test-schema: ## Test if the schema has been modified
	$(MAKE) schema
	./hack/test-generate-schema.sh

local-registry: ## Run a local docker registry
	docker run -p 5000:5000 --restart=always --name registry registry:2

clean: ## Clean up build artifacts
	rm -rf build

clean-test-artifacts: ## removes bundles and zarf packages that have been created from previous test runs
	find src/test -type f -name '*.tar.zst' -delete

push-test-artifacts: ## Push artifacts that UDS CLI tests rely on to GHCR
	cd hack && ./push-test-artifacts.sh

lint: ## Run golangci-lint on the project
	golangci-lint run ./src/...
