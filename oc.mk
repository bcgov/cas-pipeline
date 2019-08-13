OC=$(shell which oc)
OC_TOOLS_PROJECT=$(PATHFINDER_PREFIX)-tools
OC_DEV_PROJECT=$(PATHFINDER_PREFIX)-dev
OC_TEST_PROJECT=$(PATHFINDER_PREFIX)-test
OC_PROD_PROJECT=$(PATHFINDER_PREFIX)-prod
OC_CONSOLE=https://console.pathfinder.gov.bc.ca:8443/console/projects
OC_REGISTRY=docker-registry.default.svc:5000
OC_REGISTRY_EXT=docker-registry.pathfinder.gov.bc.ca
OC_PROJECT=$(shell echo "$${ENVIRONMENT:-$${OC_PROJECT}}")
OC_TEMPLATE_VARS=PREFIX=$(PROJECT_PREFIX) GIT_SHA1=$(GIT_SHA1) GIT_BRANCH_NORM=$(GIT_BRANCH_NORM)

define oc_whoami
	@@WHOAMI="$(shell $(OC) whoami)"; \
		if [ -z "$${WHOAMI}" ]; then \
			echo "✘ To log in, click 'Copy Login Command' on $(OC_CONSOLE)"; \
			exit 1; \
		fi; \
		echo "✓ logged in as: $${WHOAMI}";
endef

define oc_project
	@@$(TEST) $(OC_PROJECT) # ensure OC_PROJECT is defined
	@@$(OC) project $(OC_PROJECT) >/dev/null
	@@echo ✓ switched project to: $(OC_PROJECT)
endef

define oc_validate
	$(OC) process --ignore-unknown-parameters=true -f $(1) --local $(2) \
		| $(OC) -n "$(OC_PROJECT)" apply --dry-run --validate -f- >/dev/null \
		&& echo ✓ $(1) is valid \
		|| (echo ✘ $(1) is invalid && exit 1)
endef

define oc_lint
	@@for FILE in $(shell $(FIND) openshift -name \*.yml -print); \
		do $(call oc_validate,$$FILE,$(OC_TEMPLATE_VARS)); \
	done
endef

define oc_apply
	$(OC) process --ignore-unknown-parameters=true -f $(1) $(2) \
		| $(OC) -n "$(3)" apply --wait --overwrite --validate -f-
endef

define oc_configure
	@@for FILE in $(shell $(FIND) openshift/build -name \*.yml -print); \
		do $(call oc_apply,$$FILE,$(OC_TEMPLATE_VARS),$(OC_PROJECT)); \
	done
endef

define oc_build
	@@echo ✓ building $(1)
	@@$(OC) -n $(OC_PROJECT) start-build $(1) --follow

	@@$(eval HAS_SHA1_TAG = $(shell $(OC) -n $(OC_PROJECT) get is/$(1) -o=go-template='{{range .status.tags}}{{if eq .tag "$(GIT_SHA1)"}}{{"true"}}{{break}}{{end}}{{end}}'))

	ifeq ($(HAS_SHA1_TAG),'true')
		@@echo ✓ tagging $(1):$(GIT_SHA1) to $(1):$(GIT_BRANCH_NORM)
		@@$(OC) -n $(OC_PROJECT) tag $(1):$(GIT_SHA1) $(1):$(GIT_BRANCH_NORM)
	else
		@@$(eval IMAGE_ID = $(shell $(OC) -n $(OC_PROJECT) get istag/$(1):$(GIT_BRANCH_NORM) -o=go-template='\
{{$$commitId := index .image.dockerImageMetadata.Config.Labels "io.openshift.build.commit.id"}}\
{{if eq $$commitId "$(GIT_SHA1)"}}\
{{.image.dockerImageMetadata.Id}}\
{{end}}'))
		ifeq ($(IMAGE_ID),'')
			@@echo ✘ Image stream $(1):$(GIT_BRANCH_NORM) for commit $(GIT_SHA1) was not found.
			@@echo This is likely due to the fact that $(1):$(GIT_BRANCH_NORM) was overwritten by a parallel build
			@@exit 1
		else
			@@echo ✓ tagging $(1)@$(IMAGE_ID) to $(1):$(GIT_SHA1)
			@@$(OC) -n $(OC_PROJECT) tag $(1)@$(IMAGE_ID) $(1):$(GIT_SHA1)
		endif
	endif
endef

define oc_promote
	@@$(OC) -n $(OC_PROJECT) tag $(OC_TOOLS_PROJECT)/$(1):$(GIT_SHA1) $(1):$(GIT_SHA1) --reference-policy=local
	@@$(OC) -n $(OC_PROJECT) tag $(1):$(GIT_SHA1) $(1):latest --reference-policy=local
endef

define oc_provision
	@@for FILE in $(shell $(FIND) openshift/deploy -name \*.yml -print); \
		do $(call oc_apply,$$FILE,$(OC_TEMPLATE_VARS),$(OC_PROJECT)); \
	done
endef

# @see https://access.redhat.com/RegistryAuthentication#allowing-pods-to-reference-images-from-other-secured-registries-9
define oc_configure_credentials
	@@if ! $(OC) -n "$(1)" get secret io-redhat-registry  >/dev/null; then \
		$(OC) -n "$(1)" create secret docker-registry io-redhat-registry \
			--docker-server="$(RED_HAT_DOCKER_SERVER)" \
			--docker-username="$(RED_HAT_DOCKER_USERNAME)" \
			--docker-password="$(RED_HAT_DOCKER_PASSWORD)" \
			--docker-email="$(RED_HAT_DOCKER_EMAIL)" \
			>/dev/null; \
		$(OC) -n "$(1)" secret link default io-redhat-registry --for=pull; \
		$(OC) -n "$(1)" secret link builder io-redhat-registry; \
	fi
endef

define oc_new_project
	@@if ! $(OC) get project $(1) >/dev/null; then \
		$(OC) new-project $(1) >/dev/null \
		&& echo "✓ oc new-project $(1)"; \
	fi
	$(call oc_configure_credentials,$(1))
	@@echo "✓ oc project $(1) exists"
endef

define oc_create
	@@if ! $(OC) -n "$(1)" get $(2)/$(3) 2>&1 >/dev/null; then \
		$(OC) -n "$(1)" create $(2) $(3) >/dev/null; \
	fi;
	@@echo "✓ oc create $(2)/$(3)"
endef
