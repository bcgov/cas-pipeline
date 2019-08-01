SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../git.mk)

.PHONY: git.echo
git.echo:
	@@echo $(GIT)

.PHONY: git_sha1.echo
git_sha1.echo:
	@@echo $(GIT_SHA1)

.PHONY: git_branch.echo
git_branch.echo:
	@@echo $(GIT_BRANCH)

.PHONY: git_branch_norm.echo
git_branch_norm.echo:
	@@echo $(GIT_BRANCH_NORM)
