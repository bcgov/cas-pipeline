#!/bin/bash

OC=$1
OC_PROJECT=$2
BUILD_CONFIG=$3
GIT_BRANCH_NORM=$4
GIT_SHA1=$5

echo "✓ building $BUILD_CONFIG"
$OC -n $OC_PROJECT start-build $BUILD_CONFIG --follow

if [ "`$OC -n $OC_PROJECT get is/$BUILD_CONFIG -o=go-template='{{range .status.tags}}{{if eq .tag "$GIT_SHA1"}}{{"true"}}{{end}}{{end}}'`" == "true" ]; then
    echo "✓ tagging $BUILD_CONFIG:$GIT_SHA1 to $BUILD_CONFIG:$GIT_BRANCH_NORM"
    $OC -n $OC_PROJECT tag $BUILD_CONFIG:$GIT_SHA1 $BUILD_CONFIG:$GIT_BRANCH_NORM
else
    # Go through the last builds to find which image corresponds to the build config
    BUILD_VERSION=`$OC -n $OC_PROJECT get bc/$BUILD_CONFIG -o=go-template='{{.status.lastVersion}}'`
    while [ -z "$IMAGE_ID" ]; do
        IMAGE_ID=`$OC -n $OC_PROJECT get build/$BUILD_CONFIG-$BUILD_VERSION -o=go-template='{{if (index .metadata.labels "cas-pipeline/commit.id")}}{{if eq (index .metadata.labels "cas-pipeline/commit.id") "'$GIT_SHA1'"}}{{.status.output.to.imageDigest}}{{end}}{{end}}'`
        if [[ ! $? -eq 0 ]]; then
            # The oc command returned an error. Likely because we are trying to get a build that does not exist anymore
            exit 1
        fi
        BUILD_VERSION=$[$BUILD_VERSION - 1]
    done
    if [[ $IMAGE_ID == sha256* ]]; then
        echo "✓ tagging $BUILD_CONFIG@$IMAGE_ID to $BUILD_CONFIG:$GIT_SHA1"
        RETRIES=5
        while [ "$RETRIES" -gt 0 ]; do
            $OC -n $OC_PROJECT tag $BUILD_CONFIG@$IMAGE_ID $BUILD_CONFIG:$GIT_SHA1 > /dev/null 2>&1
            $OC -n $OC_PROJECT get istag/$BUILD_CONFIG:$GIT_SHA1 > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "✓ Image tag $BUILD_CONFIG:$GIT_SHA1 found."
                exit 0
            else
                echo "Retrying..."
                RETRIES=$[$RETRIES - 1]
                sleep 5
            fi
        done
        echo "✘ Failed to tag $BUILD_CONFIG@$IMAGE_ID to $BUILD_CONFIG:$GIT_SHA1"
        exit 1
    else
        echo "✘ Image stream $BUILD_CONFIG:$GIT_BRANCH_NORM for commit $GIT_SHA1 was not found."
        exit 1
    fi
fi
