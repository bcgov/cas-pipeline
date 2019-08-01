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
