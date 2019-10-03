THIS_FOLDER := $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../)
include $(THIS_FOLDER)/git.mk
include $(THIS_FOLDER)/jq.mk
include $(THIS_FOLDER)/red_hat.mk
include $(THIS_FOLDER)/test.mk

OC=$(shell which oc)
OC_TOOLS_PROJECT=$(PATHFINDER_PREFIX)-tools
OC_DEV_PROJECT=$(PATHFINDER_PREFIX)-dev
OC_TEST_PROJECT=$(PATHFINDER_PREFIX)-test
OC_PROD_PROJECT=$(PATHFINDER_PREFIX)-prod
OC_CONSOLE=https://console.pathfinder.gov.bc.ca:8443/console/projects
OC_REGISTRY=docker-registry.default.svc:5000
OC_REGISTRY_EXT=docker-registry.pathfinder.gov.bc.ca
OC_PROJECT=$(shell echo "$${ENVIRONMENT:-$${OC_PROJECT}}")
OC_TEMPLATE_VARS=PREFIX=$(PROJECT_PREFIX) GIT_SHA1=$(GIT_SHA1) GIT_BRANCH_NORM=$(GIT_BRANCH_NORM) OC_REGISTRY=$(OC_REGISTRY) OC_PROJECT=$(OC_PROJECT)

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
		| jq '.items[].metadata.labels=(.items[].metadata.labels + { "cas-pipeline/commit.id":"$(GIT_SHA1)" })' \
		|  $(OC) -n "$(OC_PROJECT)" apply --dry-run --validate -f- >/dev/null \
		&& echo ✓ $(1) is valid \
		|| (echo ✘ $(1) is invalid && exit 1)
endef

define oc_lint
	@@shopt -s nullglob extglob; \
		for FILE in $$(ls openshift/*/!(secret)/*.yml); do \
			$(call oc_validate,$$FILE,$(OC_TEMPLATE_VARS)); \
		done
endef

define oc_apply
	$(OC) process --ignore-unknown-parameters=true -f $(1) --local $(2) \
		| jq '.items[].metadata.labels=(.items[].metadata.labels + { "cas-pipeline/commit.id":"$(GIT_SHA1)" })' \
		| $(OC) -n "$(3)" apply --wait --overwrite --validate -f-
endef

define oc_apply_dir
	@@shopt -s globstar nullglob; \
		for FILE in $(1)/**/*.yml; do \
			$(call oc_apply,$$FILE,$(OC_TEMPLATE_VARS),$(OC_PROJECT)); \
		done
endef

define oc_configure
	$(call oc_apply_dir,openshift/build)
endef

define oc_build
	@@${THIS_FOLDER}/lib/oc_build.sh $(OC) $(OC_PROJECT) $(1) $(GIT_BRANCH_NORM) $(GIT_SHA1) "$(OC_TEMPLATE_VARS)" "$(JQ)"
endef

define oc_promote
	@@$(OC) -n $(OC_PROJECT) tag $(OC_TOOLS_PROJECT)/$(1):$(GIT_SHA1) $(1):$(GIT_SHA1) --reference-policy=local
	@@$(OC) -n $(OC_PROJECT) tag $(1):$(GIT_SHA1) $(1):latest --reference-policy=local
endef

define oc_create_secrets
    @@set -e; shopt -s nullglob; \
    for FILE in openshift/deploy/secret/*.yml; do \
        JSON="$$($(OC) process --ignore-unknown-parameters -f $$FILE $(OC_TEMPLATE_VARS))"; \
        if echo $$JSON | jq -e '.items[].kind == "Secret"' >/dev/null; then \
            NAME="$$(echo $$JSON | jq -r '.items[].metadata.name')"; \
            if ! $(OC) -n "$(OC_PROJECT)" get secret/$$NAME >/dev/null 2>&1; then \
                echo $$JSON | $(OC) -n "$(OC_PROJECT)" create --validate -f- >/dev/null; \
                echo "✓ Created secret/$$NAME"; \
            else \
                echo "- Ignored secret/$$NAME because it already exists"; \
            fi; \
        fi; \
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

define oc_mock_storageclass
	$(call oc_new_project,local-storage)
	@@${THIS_FOLDER}/lib/oc_mock_storageclass.sh "$(OC)" local-storage $(1)
endef

define oc_create
	@@if ! $(OC) -n "$(1)" get $(2)/$(3) 2>&1 >/dev/null; then \
		$(OC) -n "$(1)" create $(2) $(3) >/dev/null; \
	fi;
	@@echo "✓ oc create $(2)/$(3)"
endef

define oc_deploy
	$(call oc_apply_dir,openshift/deploy/persistentvolumeclaim)
	$(call oc_apply_dir,openshift/deploy/deploymentconfig)
	$(call oc_apply_dir,openshift/deploy/service)
	$(call oc_apply_dir,openshift/deploy/route)
	$(call oc_apply_dir,openshift/deploy/statefulset)
	$(call oc_apply_dir,openshift/deploy/cronjob)
endef

define oc_wait_for_job
	@@${THIS_FOLDER}/lib/oc_wait_for_job.sh "$(OC)" "$(OC_PROJECT)" "$(1)"
endef

define oc_wait_for_deploy_ready
	@@${THIS_FOLDER}/lib/oc_wait_for_deploy_ready.sh "$(OC)" "$(OC_PROJECT)" "$(1)" "$(JQ)"
endef

define oc_run_job
	$(call oc_wait_for_job,$(1))
	@@${THIS_FOLDER}/lib/oc_run_job.sh "$(OC)" "$(OC_PROJECT)" "$(1)" "$(JQ)" "$(OC_TEMPLATE_VARS)" "$(2)"
endef

define oc_exec_all_pods
	@@set -e; \
		PODS="$$($(OC) -n "$(OC_PROJECT)" get pod --selector deploymentconfig=$(1) --field-selector status.phase=Running -o name | cut -d '/' -f 2 | tr '\n' ' ')"; \
		PODS+=" $$($(OC) -n "$(OC_PROJECT)" get pod --selector app=$(1) --field-selector status.phase=Running -o name | cut -d '/' -f 2 | tr '\n' ' ')"; \
		for POD in $$PODS; do \
			$(OC) -n "$(OC_PROJECT)" exec $$POD -- /usr/bin/env bash -c $$'$(2)'; \
		done
endef
