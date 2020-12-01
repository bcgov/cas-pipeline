#!/bin/bash
set -euo pipefail

usage() {
    cat << EOF
$0 [OPTIONS]

Creates a 'cas-namespaces' secret in all namespaces that contains the namespaces each app is deployed to.

The list of namespaces affected by the script is defined by the
"--project-prefixes" and "--project-suffixes" options (see below).
For instance, "--project-prefixes abc123,456qwe --project-suffixes dev,test"
would affect the following namespaces: abc123-dev, abc123-test, 456qwe-dev and 456qwe-test

Maintainer: Dylan Leard <dylan@button.is>

Options:

  -pp, --project-prefixes
    The comma-separated project prefixes where the secret will be added. e.g. "abc123,456qwe"
  -ps, --project-suffixes
    The comma-separated project suffixes where the secret will be added. Defaults to "dev,test,prod"
  -ap, --airflow-prefix
    The namespace prefix that airflow is deployed to
  -gp, --ggircs-prefix
    The namespace prefix that ggircs is deployed to
  -cp, --ciip-prefix
    The namespace prefix that ciip is deployed to
  --dry-run
    Prints the list of roles bindings that would be created without applying the changes
  -h, --help
    Prints this message

EOF
}

# default options
dry_run="none"
declare -a suffixes=("dev" "test" "prod")

while [[ -n ${1+x} && "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -pp | --project-prefixes )
    shift
    IFS=',' read -r -a prefixes <<< "$1"
    ;;
  -ps | --project-suffixes )
    shift
    IFS=',' read -r -a suffixes <<< "$1"
    ;;
  -ap | --airflow-prefix )
    shift
    airflow_prefix=$1
    ;;
  -gp | --ggircs-prefix )
    shift
    ggircs_prefix=$1
    ;;
  -cp | --ciip-prefix )
    shift
    ciip_prefix=$1
    ;;
  --dry-run )
    dry_run="client"
    ;;
  -h | --help )
    usage
    exit 0
    ;;
esac; shift; done

__dirname="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "Creating cas-namespaces secret in all dev,test,prod namespaces"

for prefix in "${prefixes[@]}"; do
  for suffix in "${suffixes[@]}"; do
    namespace=$prefix-$suffix
    airflow_namespace=$airflow_prefix-$suffix
    ggircs_namespace=$ggircs_prefix-$suffix
    ciip_namespace=$ciip_prefix-$suffix
    oc process -f "$__dirname"/../openshift/authorize/secret/namespaceSecret.yml \
    NAMESPACE="$namespace" \
    AIRFLOW_NAMESPACE="$airflow_namespace" \
    GGIRCS_NAMESPACE="$ggircs_namespace" \
    CIIP_NAMESPACE="$ciip_namespace" \
    | oc -n "$namespace" apply --wait --overwrite --validate --dry-run="$dry_run" -f -
  done
done
