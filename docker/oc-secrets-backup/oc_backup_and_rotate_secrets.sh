#! /usr/bin/env bash
set -euxo pipefail

# Validate that the required environment variables are set
OC_PROJECT_PREFIXES=$NAMESPACES
WORKSPACE=$WORKSPACE
BACKUP_VOLUME=$BACKUP_VOLUME

####################################################
# Fetch secrets and store them in a single archive #
####################################################

echo "Found namespaces: $OC_PROJECT_PREFIXES"
OC_PROJECT_SUFFIXES="dev,tools"

folder="oc_secret_dump"
mkdir -p "$WORKSPACE/$folder"

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

tar -zcvf "$BACKUP_VOLUME/$folder.tar.gz" $WORKSPACE/$folder
rm -r $WORKSPACE/$folder

echo "All secrets have been backed up in $BACKUP_VOLUME/$folder.tar.gz! Don't forget to save them somewhere safe."

#####################################################
# Use Logrotate to save them on different schedules #
#####################################################

mkdir -p $BACKUP_VOLUME/daily
mkdir -p $BACKUP_VOLUME/weekly
mkdir -p $BACKUP_VOLUME/monthly
mkdir -p $BACKUP_VOLUME/yearly

logrotate -s $BACKUP_VOLUME/logrotate.daily.status /logrotate-configs/logrotate.daily.conf
logrotate -s $BACKUP_VOLUME/logrotate.weekly.status /logrotate-configs/logrotate.weekly.conf
logrotate -s $BACKUP_VOLUME/logrotate.monthly.status /logrotate-configs/logrotate.monthly.conf
logrotate -s $BACKUP_VOLUME/logrotate.yearly.status /logrotate-configs/logrotate.yearly.conf

