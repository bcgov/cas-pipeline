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
