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
# The gcs_terraform_buckets shells script is not idempotent (fails if buckets exist) & needs to be commented out for the helm_deploy script to run.
  @@source .env; ./lib/gcs_terraform_buckets.sh -pp $$OC_PROJECT_PREFIXES -gcp $$GCP_PROJECT
	@@source .env; ./lib/helm_deploy.sh -pp $$OC_PROJECT_PREFIXES -c ./helm/cas-provision/ -n cas-provision -v $$VALUES_FILE_PATH

.PHONY: provision_artifactory
provision_artifactory: ## Install the artifactory chart, creating an artifactory service account in every namespace. Should only be run once.
provision_artifactory:
	$(call oc_whoami)
	@@source .env; ./lib/helm_deploy.sh -pp $$OC_PROJECT_PREFIXES -c ./helm/cas-provision-artifactory/ -n cas-provision-artifactory -v $$VALUES_FILE_PATH

.PHONY: lint_monitoring_chart
lint_monitoring_chart: ## Checks the configured helm chart template definitions against the remote schema
lint_monitoring_chart:
	@set -euo pipefail; \
	if [ -z '$(CIIP_NAMESPACE_PREFIX)' ]; then \
		echo "CIIP_NAMESPACE_PREFIX is not set"; \
		exit 1; \
	fi; \
	helm dep up ./helm/crunchy-monitoring; \
	helm template --set namespace=$(CIIP_NAMESPACE_PREFIX)-tools -f ./helm/crunchy-monitoring/values.yaml crunchy-monitoring ./helm/crunchy-monitoring --validate;

.PHONY: install_crunchy_monitoring
install_crunchy_monitoring: ## Installs the helm chart on the OpenShift cluster
install_crunchy_monitoring: NAMESPACE=$(CIIP_NAMESPACE_PREFIX)-tools
install_crunchy_monitoring: CHART_DIR=./helm/crunchy-monitoring
install_crunchy_monitoring: CHART_INSTANCE=crunchy-monitoring
install_crunchy_monitoring: HELM_OPTS=--atomic --wait-for-jobs --timeout 2400s --namespace $(NAMESPACE) \
	--values $(CHART_DIR)/.crunchy-values.yaml
install_crunchy_monitoring:
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
