#!/bin/bash

OC=$1
OC_PROJECT=$2
JOB_NAME=$3

get_job_phase() {
    $OC -n "$OC_PROJECT" get pods --selector job-name="$JOB_NAME" --sort-by='{.metadata.resourceVersion}' -o json | jq ".items[-1].status.phase"
}

echo -n "Waiting for previous job to complete"
while [[ $(get_job_phase) == '"Pending"' || $(get_job_phase) == '"Running"' || $(get_job_phase) == '"Unknown"' ]]; do
    echo -n "."
    sleep 5
done
echo ""
