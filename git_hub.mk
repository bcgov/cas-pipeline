GITHUB_DOCKER_SERVER=$(shell echo "$$GITHUB_DOCKER_SERVER")
GITHUB_DOCKER_USERNAME=$(shell echo "$$GITHUB_DOCKER_USERNAME")
GITHUB_DOCKER_TOKEN=$(shell echo "$$GITHUB_DOCKER_TOKEN")
GITHUB_SECRET_NAME=github-registry

define oc_configure_github_credentials
	$(call oc_configure_credentials,$(1),$(GITHUB_SECRET_NAME),$(GITHUB_DOCKER_SERVER),$(GITHUB_DOCKER_USERNAME),$(GITHUB_DOCKER_TOKEN))
endef
