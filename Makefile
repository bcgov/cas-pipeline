SHELL := /usr/bin/env bash

THIS_FOLDER := $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../)
include $(THIS_FOLDER)/make.mk
PIPELINE_TESTS = $(call make_recursive_wildcard,$(THIS_FOLDER),*.bats)

ifeq ($(MAKECMDGOALS),lint)
include $(THIS_FOLDER)/test/shellcheck.mk
endif
.PHONY: lint
lint: # https://github.com/koalaman/shellcheck
	$(call shellcheck_lint,$(PIPELINE_TESTS))

ifeq ($(MAKECMDGOALS),test)
include $(THIS_FOLDER)/test/bats.mk
endif
.PHONY: test
test: # https://github.com/bats-core/bats-core
	$(call bats_test,$(PIPELINE_TESTS))

ifeq ($(MAKECMDGOALS),authorize)
include $(THIS_FOLDER)/oc.mk
PATHFINDER_PREFIX := wksv3k
PROJECT_PREFIX := cas-
endif

# Make authorize / provision uses variables and a values.yaml file that are protected in BCCAS OnePassword.

.PHONY: authorize
authorize:
	$(call oc_whoami)
	# Synchronize rolebindings with GitHub teams
	@@source .env; ./lib/oc_add_gh_team_to_nsp.sh --token $$GH_TOKEN -t $$GH_ADMINS_TEAM -pp $$OC_PROJECT_PREFIXES -r admin
	@@source .env; ./lib/oc_add_gh_team_to_nsp.sh --token $$GH_TOKEN -t $$GH_DEVELOPERS_TEAM -pp $$OC_PROJECT_PREFIXES -r view

# Target to provision secrets, service accounts and more in namespaces, via the attached helm chart
.PHONY: provision
provision:
	$(call oc_whoami)
	@@source .env; ./lib/helm_deploy.sh -pp $$OC_PROJECT_PREFIXES -c ./helm/cas-provision/ -v $$VALUES_FILE_PATH

.PHONY: lint_monitoring_chart
lint_monitoring_chart: ## Checks the configured helm chart template definitions against the remote schema
lint_monitoring_chart:
	@set -euo pipefail; \
	helm dep up ./helm/crunchy-monitoring; \
	helm template -f ./helm/crunchy-monitoring/values.yaml crunchy-monitoring ./helm/crunchy-monitoring --validate;

.PHONY: install_crunchy_monitoring
install: ## Installs the helm chart on the OpenShift cluster
install: NAMESPACE=$(CIIP_NAMESPACE_PREFIX)-tools
install: CHART_DIR=./helm/crunchy_monitoring
install: CHART_INSTANCE=crunchy_monitoring
install: HELM_OPTS=--atomic --wait-for-jobs --timeout 2400s --namespace $(NAMESPACE) \
										--values $(CHART_DIR)/values.yaml
install:
	@set -euo pipefail; \
	if [ -z '$(CIIP_NAMESPACE_PREFIX)' ]; then \
		echo "CIIP_NAMESPACE_PREFIX is not set"; \
		exit 1; \
	fi; \
	helm dep up $(CHART_DIR); \
	if ! helm status --namespace $(NAMESPACE) $(CHART_INSTANCE); then \
		helm install $(HELM_OPTS) $(CHART_INSTANCE) $(CHART_DIR); \
	fi; \
	helm upgrade $(HELM_OPTS) $(CHART_INSTANCE) $(CHART_DIR);
