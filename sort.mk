SORT := $(shell command -v sort)

ifeq ($(SORT),)
$(error 'sort' not found in $$PATH)
endif
