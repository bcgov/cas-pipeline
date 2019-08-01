SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../make.mk)

.PHONY: make_this_makefile.echo
make_this_makefile.echo:
	@@echo $(make_this_makefile)

.PHONY: make_other_makefile.echo
make_other_makefile.echo:
	@@echo $(make_other_makefile)

.PHONY: make_parent_makefile.echo
make_parent_makefile.echo:
	@@echo $(make_parent_makefile)

.PHONY: help
help:
	@@echo $(make_need_help)

.PHONY: make_need_help.echo
make_need_help.echo:
	@@echo $(make_need_help)

.PHONY: make_help.call
make_help.call:
	@@$(call make_help,one,two)
