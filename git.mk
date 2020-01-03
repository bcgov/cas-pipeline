GIT=$(shell command -v git)
ifeq ($(GIT),)
$(error 'git' not found in $$PATH)
endif

GIT_SHA1=$(shell $(GIT) rev-parse HEAD)
GIT_BRANCH=$(strip $(shell $(GIT) rev-parse --abbrev-ref HEAD))
GIT_BRANCH_NORM=$(subst /,-,$(GIT_BRANCH)) # openshift doesn't like slashes
