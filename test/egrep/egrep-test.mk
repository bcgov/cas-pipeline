SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../egrep.mk)

.PHONY: egrep.echo
egrep.echo:
	@@echo $(EGREP)
