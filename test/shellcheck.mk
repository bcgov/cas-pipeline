SHELLCHECK := $(shell command -v shellcheck)

ifeq ($(SHELLCHECK),)
$(error 'shellcheck' not found in $$PATH)
endif

define shellcheck_lint
@@$(SHELLCHECK) $(1)
@@echo ✓ completed lint
endef
