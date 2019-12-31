#!/bin/bash

# =============================================================================
# Usage:
# -----------------------------------------------------------------------------
usage() {
    cat << EOF
$0

Creates OpenShift storage class(es) without provisioner and persistent volumes using
Kubernetes' local persistent volumes (https://kubernetes.io/docs/concepts/storage/volumes/#local)
To cover most testing scenarios, this script creates 100 volumes per storage class.

Usage: $0 OC_COMMAND PROJECT STORAGECLASS...
EOF
    exit 1
}

num_required_params=3
if [ "$#" -lt "$num_required_params" ]; then
    echo "Passed $# parameters. Expected at least $num_required_params."
    usage
fi

set -e

oc=$1
shift
project=$1
shift
storage_classes=("$@")
project_path=$(pwd)
if [[ ! -d  "$project_path/openshift.local.clusterup" ]]; then
  echo "Could not find the \'openshift.local.clusterup\' directory in the current working directory."
  echo "This script should be executed in the same working directory as \`oc cluster up\`."
  exit 1
fi

cat >> /tmp/local-volume-config.yml <<EOL
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-volume-config
data:
EOL

pids=""
for sc in "${storage_classes[@]}"; do
    cat >> "/tmp/storage-$sc.yml" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
 name: $sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
    $oc -n "$project" create -f "/tmp/storage-$sc.yml"

    for pv_num in {1..100}; do
      mkdir -p "$project_path/openshift.local.clusterup/openshift.local.pv/$sc-$pv_num";
      cat >> "/tmp/pv-$sc-$pv_num.yml" <<EOL
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-$sc-$pv_num
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteOnce
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: $sc
  local:
    path: $project_path/openshift.local.clusterup/openshift.local.pv/$sc-$pv_num
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - localhost
EOL
      $oc -n "$project" create -f "/tmp/pv-$sc-$pv_num.yml" &
      pids="$pids $!"
    done
done
for pid in $pids; do
  wait "$pid"
done
