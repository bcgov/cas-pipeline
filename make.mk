include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../awk.mk)
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../egrep.mk)
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../sort.mk)

# make_this_makefile := $(call make_get_last_element,$(MAKEFILE_LIST))
# make_other_makefiles := $(filter-out $(make_this_makefile),$(MAKEFILE_LIST))
# make_parent_makefile := $(call make_get_last_element,$(make_other_makefiles))
make_need_help := $(filter help,$(MAKECMDGOALS))

define make_help
$(if $(make_need_help),$(warning $1 -- $2))
endef

# define make_get_last_element
# $(word $(words $1),$1)
# endef

define make_recursive_wildcard
$(strip $(wildcard $1$2)$(foreach d,$(wildcard $1*),$(call make_recursive_wildcard,$d/,$2)))
endef

# deprecated: unnecessary dependencies
define make_list_targets
@@$(MAKE) -pRrq -f $(1) : 2>/dev/null \
	| $(AWK) -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
	| $(SORT) \
	| $(EGREP) -v -e '^[^[:alnum:]]' -e '^$@$$'
endef
