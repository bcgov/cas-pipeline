SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../awk.mk)

.PHONY: awk.echo
awk.echo:
	@@echo $(AWK)
