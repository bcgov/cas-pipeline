#!/bin/bash


# =============================================================================
# Usage:
# -----------------------------------------------------------------------------
usage() {
    cat << EOF
$0

This script cleans up obsolete imagestreams tags. It makes two assumptions on
the development process:
 - Image streams are tagged using the commit sha1
   and/or normalized branch name ("/" replaced by "-")
 - Feature branches are integrated in the 'develop' branch
   via pull requests using merge commits (not squash or rebase)

Goes through all the imagestream tags that exists on the provided imagestream,
and deletes the following tags:
 - tags that point to a git object (commit or branch) which
   do not exist in the current git repository
 - tags that point to a git commit which is available in the "develop" branch,
   but is not a merge commit

If a git commit has a git tag pointing to it,
the corresponding imagestream tag will never be deleted

Usage: $0 OC_COMMAND PROJECT IMAGE_STREAM_NAME GIT_EXECUTABLE...
EOF
    exit 1
}

num_required_params=4
if [ "$#" -ne "$num_required_params" ]; then
    echo "Passed $# parameters. Expected at $num_required_params."
    usage
fi

set -e

oc=$1
oc_project=$2
image_stream=$3
git=$4

IFS=' ' read -ra istags <<< "$($oc get  -n "$oc_project" is/"$image_stream" -o go-template='{{ range .spec.tags }}{{.name}} {{end}}')"
$git fetch --tags
for istag in "${istags[@]}"
do
    if [ -z "$($git tag --points-at "$istag")" ]; then # never delete imagestream tag if there is a git tag pointing at it
        if [ "$($git cat-file -t "$istag" 2>/dev/null)" != "commit" ]; then # both commits and branches return the type "commit"
            # Delete tags pointing to objects that do not exist anymore
            $oc -n "$oc_project" delete istag/"$image_stream":"$istag"
        elif $git branch --contains "$istag" | grep -q -E '(develop|master)'; then
            # The tag is on develop or master
            if [ "$($git log --pretty=%P -n 1 "$istag" | wc -w)" -eq 1 ]; then
                # the tag is now in develop or master but is not a merge commit
                $oc -n "$oc_project" delete istag/"$image_stream":"$istag"
            fi
        fi
    fi
done
