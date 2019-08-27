EGREP := $(shell command -v egrep)

ifeq ($(EGREP),)
$(error 'egrep' not found in $$PATH)
endif
