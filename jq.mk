JQ := $(shell command -v jq)

ifeq ($(JQ),)
$(error 'jq' not found in $$PATH)
endif
