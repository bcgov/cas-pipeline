FIND := $(shell command -v find)

ifeq ($(FIND),)
$(error 'find' not found in $$PATH)
endif
