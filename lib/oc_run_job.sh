#!/bin/bash

OC=$1
OC_REGISTRY=$2
OC_PROJECT=$3
JOB_NAME=$4
GIT_BRANCH_NORM=$5
GIT_SHA1=$6
PROJECT_PREFIX=$7
JQ=$8


get_job_phase() {
    $OC -n "$OC_PROJECT" get pods --selector job-name="$JOB_NAME" --sort-by='{.metadata.resourceVersion}' -o json | jq ".items[-1].status.phase"
}

echo -n "Waiting for previous job to complete"
while [[ $(get_job_phase) == '"Pending"' || $(get_job_phase) == '"Running"' || $(get_job_phase) == '"Unknown"' ]]; do
    echo -n "."
    sleep 5
done
echo ""
$OC -n "$OC_PROJECT" delete job "$JOB_NAME"

# Find the job config for this job and run `oc apply` for it
shopt -s globstar nullglob
for FILE in openshift/deploy/job/**/*.yml; do
    JOB_CONFIG_STRING=$($OC process --ignore-unknown-parameters=true -f "$FILE" PREFIX="$PROJECT_PREFIX" GIT_SHA1="$GIT_SHA1" GIT_BRANCH_NORM="$GIT_BRANCH_NORM" OC_REGISTRY="$OC_REGISTRY" OC_PROJECT="$OC_PROJECT" \
    | $JQ "if .items[].metadata.name == \"$JOB_NAME\" then .items[].metadata.labels=(.items[].metadata.labels + { \"cas-pipeline/commit.id\":\"$GIT_SHA1\" }) else empty end")
    if [[ -n "$JOB_CONFIG_STRING" ]]; then
        echo "$JOB_CONFIG_STRING" | "$OC" -n "$OC_PROJECT" apply --wait --overwrite --validate -f-
    fi
done

echo -n "Waiting for job to complete"
while [[ $(get_job_phase) == '"Pending"' || $(get_job_phase) == '"Running"' || $(get_job_phase) == '"Unknown"' ]]; do
    echo -n "."
    sleep 5
done
echo ""

if [[ $(get_job_phase) == '"Succeeded"' ]]; then
    echo "✓ Job succeeded."
    exit 0
elif [[ $(get_job_phase) == '"Failed"' ]]; then
    echo "✘ Job failed."
    exit 1
fi
