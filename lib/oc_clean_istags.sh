#!/bin/bash

OC=$1
OC_PROJECT=$2
BUILD_CONFIG=$3
GIT=$4

IFS=' ' read -ra istags <<< "$($OC get  -n "$OC_PROJECT" is/"$BUILD_CONFIG" -o go-template='{{ range .spec.tags }}{{.name}} {{end}}')"
$GIT fetch --tags
for istag in "${istags[@]}"
do
    if [ -z "$($GIT tag --points-at "$istag")" ]; then # never delete imagestream tag if there is a git tag pointing at it
        if [ "$($GIT cat-file -t "$istag" 2>/dev/null)" != "commit" ]; then # both commits and branches return the type "commit"
            # Delete tags pointing to objects that do not exist anymore
            $OC -n "$OC_PROJECT" delete istag/"$BUILD_CONFIG":"$istag"
        elif $GIT branch --contains "$istag" | grep -q -E '(develop|master)'; then
            # The tag is on develop or master
            if [ "$($GIT log --pretty=%P -n 1 "$istag" | wc -w)" -eq 1 ]; then
                # the tag is now in develop or master but is not a merge commit
                $OC -n "$OC_PROJECT" delete istag/"$BUILD_CONFIG":"$istag"
            fi
        fi
    fi
done
