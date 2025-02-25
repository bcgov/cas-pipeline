#! /bin/bash
set -euo pipefail

OC_PROJECT_PREFIXES=$1

echo "Found namespaces: $OC_PROJECT_PREFIXES"
OC_PROJECT_SUFFIXES="dev,test,prod,tools"

folder="oc_secret_dump-$(date +%Y_%m_%d_%Hh%Mm%Ss)"
mkdir -p $folder

IFS=','
read -r -a prefixes <<< "$OC_PROJECT_PREFIXES"
read -r -a suffixes <<< "$OC_PROJECT_SUFFIXES"


for prefix in "${prefixes[@]}"; do
    for suffix in "${suffixes[@]}"; do
        namespace=$prefix-$suffix
        echo "Fetching secrets for $namespace ..."
        oc get secrets -n $namespace -o json | jq '.items[] | {name: .metadata.name,data: .data}' > "./$folder/$namespace.json"
    done
done

tar -zcvf "$folder.tar.gz" $folder
rm -r $folder

echo "All secrets have been backed up in $folder.tar.gz! Don't forget to save them somewhere safe."

