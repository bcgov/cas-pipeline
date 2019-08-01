AWK := $(shell command -v awk)

ifeq ($(AWK),)
$(error 'awk' not found in $$PATH)
endif
