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
   do not exist in the current git repository, or is unreachable
 - tags that point to a git commit which is available in the "develop" branch,
   but is not a merge commit

The remaining commits (merge commits on develop or master) are then listed,
and the 20 most recent tags are kept, older tags are deleted.

If a git commit has a git tag pointing to it,
the corresponding imagestream tag will never be deleted

Usage: $0 OC_COMMAND PROJECT IMAGE_STREAM_NAME GIT_EXECUTABLE ...
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

# strip 'origin/' and replace '/' by '-' in branch names
mapfile -t normalized_branches <<< "$(git branch -r | sed 's/origin\///g' | tr '/' '-' | tr -d ' ')"

kept_istags=$(mktemp)

for istag in "${istags[@]}"
do
    if [[ "$($git cat-file -t "$istag" 2>/dev/null)" != "commit" && ! "${normalized_branches[*]}" =~ (^| )"${istag}"( |$) ]]; then
        # Delete tags pointing to objects that do not exist anymore
        # both commits and branches return the type "commit"
        $oc -n "$oc_project" delete istag/"$image_stream":"$istag"
        echo "$istag doesn't exist in the repo"
    elif [[ "$($git cat-file -t "$istag" 2>/dev/null)" == "commit" && -z $($git branch --contains "$istag") ]]; then
        # Delete tags pointing to commits that are unreacheable
        $oc -n "$oc_project" delete istag/"$image_stream":"$istag"
        echo "$istag was unreachable"
    elif $git branch --contains "$istag" | grep -q -E '(develop|master)'; then
        # The tag is on develop or master
        if [ "$($git log --pretty=%P -n 1 "$istag" | wc -w)" == "1" ]; then
            # the tag is now in develop or master but is not a merge commit
            if [ -z "$($git tag --points-at "$istag" 2>/dev/null)" ]; then # never delete imagestream tag if there is a git tag pointing at it
                $oc -n "$oc_project" delete istag/"$image_stream":"$istag"
                echo "$istag is not a merge commit"
            else
                echo "Keeping $image_stream:$istag because a Git tag points at it"
            fi;
        elif [[ ! "${normalized_branches[*]}" =~ (^| )"${istag}"( |$) ]]; then
            # The tag is not a branch. Candidate for deletion based on age
            echo "${istag}" >> "$kept_istags"
        fi
    fi
done

counter=0
git rev-list master | while read -r sha1; do
    if grep -q "$sha1" "$kept_istags"; then
        _=$((counter++))
        if [ $counter -le 20 ]; then
            echo "keeping $sha1"
        else
            if [ -z "$($git tag --points-at "$istag" 2>/dev/null)" ]; then
                $oc -n "$oc_project" delete istag/"$image_stream":"$sha1"
            else
                echo "Keeping $image_stream:$istag because a Git tag points at it"
            fi;
        fi
    fi
done
