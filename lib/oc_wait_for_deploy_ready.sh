#!/bin/bash

OC=$1
OC_PROJECT=$2
DEPLOY_NAME=$3
JQ=$4
# TODO: handle failed/cancelled/missing deployments in OpenShift
REPLICATION_CONTROLLER_NAME="$DEPLOY_NAME-$($OC -n "$OC_PROJECT" get dc "$DEPLOY_NAME" -o go-template='{{.status.latestVersion}}')"

echo -n "Waiting for $REPLICATION_CONTROLLER_NAME to be ready"

get_deployment_pods() {
    $OC -n "$OC_PROJECT" get pod --selector deployment="$REPLICATION_CONTROLLER_NAME" -o json
}

while [[ -z $(get_deployment_pods | $JQ '.items[].status.conditions[] | select(.status=="True") | select(.type=="Ready")') ]]; do
    echo -n "."

    if [[ "Failed" == $($OC -n "$OC_PROJECT" get "rc/$REPLICATION_CONTROLLER_NAME" -o go-template='{{ index .metadata.annotations "openshift.io/deployment.phase" }}') ]]; then
        echo ""
        echo "✘ Deployment failed"
        exit 1
    fi

    sleep 5
done
echo ""
