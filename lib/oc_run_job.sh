#!/bin/bash

OC=$1
OC_PROJECT=$2
JOB_NAME=$3
JQ=$4
IFS=' ' read -ra OC_TEMPLATE_VARS <<< "$5"
IFS=' ' read -ra OC_TEMPLATE_VARS_OVERRIDE <<< "$6"

for i in "${!OC_TEMPLATE_VARS_OVERRIDE[@]}"
do
    IFS='=' read -ra TEMPLATE_VAR <<< "${OC_TEMPLATE_VARS_OVERRIDE[i]}"
    OC_TEMPLATE_VARS=("${OC_TEMPLATE_VARS[@]/#${TEMPLATE_VAR[0]}=*/${OC_TEMPLATE_VARS_OVERRIDE[i]}}")
done

for i in "${!OC_TEMPLATE_VARS[@]}"
do
    IFS='=' read -ra TEMPLATE_VAR <<< "${OC_TEMPLATE_VARS[i]}"
    if [ "${TEMPLATE_VAR[0]}" == 'GIT_SHA1' ]; then
        GIT_SHA1="${TEMPLATE_VAR[1]}"
    fi
done

get_job_phase() {
    # We select the last job as previous failed jobs would still be returned by this selector
    $OC -n "$OC_PROJECT" get pods --selector job-name="$JOB_NAME" --sort-by='{.metadata.resourceVersion}' -o json | jq ".items[-1].status.phase"
}

echo "✓ removing old config for $JOB_NAME"
$OC -n "$OC_PROJECT" delete job "$JOB_NAME"

# Find the job config for this job and run `oc apply` for it
shopt -s globstar nullglob
for FILE in openshift/deploy/job/**/*.yml; do
    JOB_CONFIG_STRING=$($OC process --ignore-unknown-parameters=true -f "$FILE" "${OC_TEMPLATE_VARS[@]}" \
    | $JQ "if .items[].metadata.name == \"$JOB_NAME\" then .items[].metadata.labels=(.items[].metadata.labels + { \"cas-pipeline/commit.id\":\"$GIT_SHA1\" }) else empty end")
    if [[ -n "$JOB_CONFIG_STRING" ]]; then
        echo "✓ triggering job $JOB_NAME"
        echo "$JOB_CONFIG_STRING" | "$OC" -n "$OC_PROJECT" apply --wait --overwrite --validate -f-
    fi
done

echo -n "Waiting for job to start"

while true; do
    case $(get_job_phase) in
        Pending | Unknown )
            echo -n "."
            sleep 5
            ;;
        Running )
            echo ""
            # This loop makes the script attempt to read the logs again in case of an unexpected EOF
            pod_name="$($OC -n "$OC_PROJECT" get pods --selector job-name="$JOB_NAME" --sort-by='{.metadata.resourceVersion}' -o json | jq ".items[-1].metadata.name")"
            pod_name="${pod_name#\"}" # remove prefix double quote from pod_name
            pod_name="${pod_name%\"}" # remove suffix double quote from pod_name
            echo "✓ running job $JOB_NAME in $pod_name"
            "$OC" -n "$OC_PROJECT" logs "$pod_name" --follow
            sleep 5
            ;;
        Succeeded )
            echo ""
            echo "✓ Job succeeded."
            exit 0
            ;;
        Failed )
            echo ""
            echo "✘ Job failed."
            exit 1
            ;;
    esac
done
