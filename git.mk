GIT=$(shell command -v git)
GIT_SHA1=$(shell echo "$${CIRCLE_SHA1:-`$(GIT) rev-parse HEAD`}")
GIT_BRANCH=$(strip $(shell $(GIT) rev-parse --abbrev-ref HEAD))
GIT_BRANCH_NORM=$(subst /,-,$(GIT_BRANCH)) # openshift doesn't like slashes

ifeq ($(GIT),)
	$(error 'git' not found in $$PATH)
endif
