# SBOM Generator Benchmark. Everything runs in the tool image, so the host needs only Docker, make and git.
#
#   make            build the image and the test cases, run every tool, score, rebuild the SBOM Generator Index (docs/)
#   make clean      remove what the build left behind; the report and the committed SBOMs stay
#   make help       every target
#
# Narrow a run with variables:   make CASE=spring-node   make STAGES="source artefact"   make TOOLS="syft trivy"

CASE   ?=
STAGES ?=
TOOLS  ?=
IMAGE_NAME ?= sbom-generator-benchmark:local
export BENCHMARK_IMAGE := $(IMAGE_NAME)

EVALUATE_ARGS := $(if $(STAGES),--stages "$(STAGES)") $(if $(TOOLS),--tools "$(TOOLS)") $(CASE)

.DEFAULT_GOAL := all
.PHONY: all image build evaluate report scan shell clean distclean help

all: ## Image, test cases, every tool, scores and the site: the whole benchmark
	scripts/evaluate $(EVALUATE_ARGS)

image: ## Build the tool image from tools/versions.env (only if missing or out of date)
	scripts/evaluate --image-only

build: ## Build the test cases in the image, without running any tool
	scripts/evaluate --build-only $(CASE)

evaluate: ## Run the tools and rebuild the report, building only test cases that are not built yet
	scripts/evaluate --no-build $(EVALUATE_ARGS)

report: ## Re-score the SBOMs already in criteria/output and rebuild docs/, running no tools
	scripts/evaluate --report-only

scan: ## Scan another source tree: make scan TREE=/path [ARTEFACT=..] [SCAN_IMAGE=..] [EXCLUDE=".."] [EXPECTED=..]
	@test -n "$(TREE)" || { echo 'usage: make scan TREE=/path/to/project [ARTEFACT=target/app.jar] [SCAN_IMAGE=name:tag] [EXCLUDE="target node_modules"] [EXPECTED=truth.json]'; exit 2; }
	scripts/scan "$(TREE)" $(if $(ARTEFACT),--artefact "$(ARTEFACT)") $(if $(SCAN_IMAGE),--image "$(SCAN_IMAGE)") \
	  $(if $(EXCLUDE),--exclude "$(EXCLUDE)") $(if $(EXPECTED),--expected "$(EXPECTED)") $(if $(TOOLS),--tools "$(TOOLS)")

shell: ## Open a shell in the tool image with the repository mounted
	scripts/evaluate --shell

# `git clean -X` removes only what .gitignore names (target/, node_modules/, .venv/, .maven-repo/ and so on), so it
# cannot touch a tracked file or anything you have not ignored. The image-stage SBOMs in criteria/output are ignored
# too, but they are inputs to `make report`, so clean stays out of that directory.
clean: ## Remove build outputs of the test cases and sample app, their container images, and caches
	git clean -fdXq testcases sample-app
	find . -name __pycache__ -type d -not -path './.git/*' -prune -exec rm -rf {} +
	@imgs=$$(docker images -q --filter 'reference=criteria-*:local' 2>/dev/null); \
	  if [ -n "$$imgs" ]; then docker rmi $$imgs >/dev/null && echo "removed test-case images"; fi
	@echo "clean: build outputs removed; docs/, criteria/output and the tool image are kept"

distclean: clean ## clean, then also remove the tool image and its cache volumes (the next run rebuilds and re-downloads)
	find criteria/output -name '*.conformance.json' -delete
	-docker rmi $(IMAGE_NAME)
	-docker volume rm sbom-benchmark-m2 sbom-benchmark-cache

help: ## List the targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z]+:.*## / {printf "  make %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo; echo '  Variables: CASE=<test case>  STAGES="source artefact image"  TOOLS="<folders under tools/>"'
