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

.PHONY: authorize_pathfinder
authorize_pathfinder: OC_PROJECT=$(OC_TOOLS_PROJECT)
authorize_pathfinder:
	@@shopt -s nullglob; \
		echo "Create the roles in all projects"; \
		for FILE in openshift/authorize/role/*.yml; do \
			for PROJECT in $(OC_TOOLS_PROJECT) $(OC_TEST_PROJECT) $(OC_DEV_PROJECT) $(OC_PROD_PROJECT); do \
				$(call oc_apply,$$FILE,$(OC_TEMPLATE_VARS),$$PROJECT); \
			done; \
		done;
	$(call oc_create,$(OC_PROJECT),serviceaccount,$(PROJECT_PREFIX)circleci)
	@echo "Granting CircleCI service account linter and builder privileges to the tools project"
	@$(OC) -n $(OC_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)linter system:serviceaccount:$(OC_PROJECT):$(PROJECT_PREFIX)circleci --role-namespace=$(OC_PROJECT)
	@$(OC) -n $(OC_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)builder system:serviceaccount:$(OC_PROJECT):$(PROJECT_PREFIX)circleci --role-namespace=$(OC_PROJECT)
	$(call oc_create,$(OC_PROJECT),serviceaccount,$(PROJECT_PREFIX)shipit)
	@echo "Granting Shipit service account deployer role in all projects"
	@$(OC) -n $(OC_TOOLS_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)deployer system:serviceaccount:$(OC_TOOLS_PROJECT):$(PROJECT_PREFIX)shipit --role-namespace=$(OC_TOOLS_PROJECT)
	@$(OC) -n $(OC_TEST_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)deployer system:serviceaccount:$(OC_TOOLS_PROJECT):$(PROJECT_PREFIX)shipit --role-namespace=$(OC_TEST_PROJECT)
	@$(OC) -n $(OC_DEV_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)deployer system:serviceaccount:$(OC_TOOLS_PROJECT):$(PROJECT_PREFIX)shipit --role-namespace=$(OC_DEV_PROJECT)
	@$(OC) -n $(OC_PROD_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)deployer system:serviceaccount:$(OC_TOOLS_PROJECT):$(PROJECT_PREFIX)shipit --role-namespace=$(OC_PROD_PROJECT)
