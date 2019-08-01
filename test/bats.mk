BATS := $(shell command -v bats)

ifeq ($(BATS),)
$(error 'bats' not found in $$PATH)
endif

define bats_test
@@$(BATS) -t $(1)
@@echo ✓ completed test
endef
