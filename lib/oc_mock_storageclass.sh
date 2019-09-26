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

if [[ ! -d  "$PROJECT_PATH/openshift.local.clusterup" ]]; then
  echo "Could not find the \'openshift.local.clusterup\' directory in the current working directory."
  echo "This script should be executed in the same working directory as \`oc cluster up\`."
  exit 1
fi

set -e

OC=$1
shift
PROJECT=$1
shift
STORAGECLASSES=("$@")
PROJECT_PATH=$(pwd)

cat >> /tmp/local-volume-config.yml <<EOL
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-volume-config
data:
EOL

for sc in "${STORAGECLASSES[@]}"; do
    cat >> "/tmp/storage-$sc.yml" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
 name: $sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
    $OC -n "$PROJECT" create -f "/tmp/storage-$sc.yml"

    for pv_num in {1..100}; do
      mkdir -p "$PROJECT_PATH/openshift.local.clusterup/openshift.local.pv/$sc-$pv_num";
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
  persistentVolumeReclaimPolicy: Retain
  storageClassName: $sc
  local:
    path: $PROJECT_PATH/openshift.local.clusterup/openshift.local.pv/$sc-$pv_num
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - localhost
EOL
      $OC -n "$PROJECT" create -f "/tmp/pv-$sc-$pv_num.yml"
    done
done
