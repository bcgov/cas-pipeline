#!/bin/bash

OC=$1
OC_PROJECT=$2
BUILD_CONFIG=$3
GIT_BRANCH_NORM=$4
GIT_SHA1=$5
read -ra OC_TEMPLATE_VARS <<< "$6"
JQ=$7

# Find the build config for this build and run `oc apply` for it
shopt -s globstar nullglob
for FILE in openshift/build/buildconfig/**/*.yml; do
    BUILD_CONFIG_STRING=$("$OC" process --ignore-unknown-parameters=true -f "$FILE" "${OC_TEMPLATE_VARS[@]}" | "$JQ" "if .items[].metadata.name == \"$BUILD_CONFIG\" then .items[].metadata.labels=(.items[].metadata.labels + { \"cas-pipeline/commit.id\":\"$GIT_SHA1\" }) else empty end")
    if [[ -n "$BUILD_CONFIG_STRING" ]]; then
        echo "$BUILD_CONFIG_STRING" | "$OC" -n "$OC_PROJECT" apply --wait --overwrite --validate -f-
    fi
done

echo "✓ building $BUILD_CONFIG"
BUILD_OBJECT="$("$OC" -n "$OC_PROJECT" start-build "$BUILD_CONFIG" --output=name)"

get_build_status() {
    "$OC" -n "$OC_PROJECT" get "$BUILD_OBJECT" -o=go-template='{{.status.phase}}'
}

echo -n "Waiting for $BUILD_OBJECT to start "
while [[ $(get_build_status) == "New" || $(get_build_status) == "Pending" ]]; do
    sleep 5
    echo -n "."
done
echo ""

while [[ $(get_build_status) == "Running" ]]; do
    # This loop makes the script attempt to read the logs again in case of an unexpected EOF
    "$OC" -n "$OC_PROJECT" logs "$BUILD_OBJECT" --follow
    sleep 5
done

if [[ $(get_build_status) != "Complete" ]]; then
    echo "✘ build $BUILD_OBJECT ended with status $(get_build_status)."
    echo "message: $("$OC" -n "$OC_PROJECT" get "$BUILD_OBJECT" -o=go-template='{{.status.message}}')"
    exit 1
fi

IMAGE_ID=$("$OC" -n "$OC_PROJECT" get "$BUILD_OBJECT" -o=go-template='{{.status.output.to.imageDigest}}')

"$OC" -n "$OC_PROJECT" tag "$BUILD_CONFIG@$IMAGE_ID" "$BUILD_CONFIG:$GIT_SHA1"
"$OC" -n "$OC_PROJECT" tag "$BUILD_CONFIG@$IMAGE_ID" "$BUILD_CONFIG:$GIT_BRANCH_NORM"
