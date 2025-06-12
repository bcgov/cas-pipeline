#! /usr/bin/env bash
set -euo pipefail

OC_PROJECT_PREFIXES=$1

WORKSPACE=$WORKSPACE

echo "Found namespaces: $OC_PROJECT_PREFIXES"
OC_PROJECT_SUFFIXES="dev,test,prod,tools"

folder="oc_secret_dump"
mkdir -p $folder

IFS=','
read -r -a prefixes <<< "$OC_PROJECT_PREFIXES"
read -r -a suffixes <<< "$OC_PROJECT_SUFFIXES"


for prefix in "${prefixes[@]}"; do
    for suffix in "${suffixes[@]}"; do
        namespace=$prefix-$suffix
        echo "Fetching secrets for $namespace ..."
        kubectl get secrets -n $namespace -o json | jq '.items[] | {name: .metadata.name,data: .data}' > "$WORKSPACE/$folder/$namespace.json"
    done
done

tar -zcvf "$WORKSPACE/$folder.tar.gz" $WORKSPACE/$folder
rm -r $WORKSPACE/$folder

echo "All secrets have been backed up in $WORKSPACE/$folder.tar.gz! Don't forget to save them somewhere safe."

