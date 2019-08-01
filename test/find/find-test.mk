SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../find.mk)

.PHONY: find.echo
find.echo:
	@@echo $(FIND)
