#!/bin/bash
set -euo pipefail

usage() {
    cat << EOF
$0 [OPTIONS]

Creates the most basic NetworkSecurityPolicies required by our architecture.

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
    Prints the list of NSPs that would be created without applying the changes
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

echo "Creating basic NetworkSecurityPolicies"

for prefix in "${prefixes[@]}"; do
  for suffix in "${suffixes[@]}"; do
    namespace="$prefix-$suffix"
    airflow_namespace="$airflow_prefix-$suffix"
    ggircs_namespace="$ggircs_prefix-$suffix"
    ciip_namespace="$ciip_prefix-$suffix"

    # Ship-it(deployer) to all namespaces
    oc process -f "$__dirname"/../openshift/authorize/networkSecurityPolicy/deployerAllNamespaces.yml \
    NAMESPACE="$namespace" \
    | oc -n "$namespace" apply --wait --overwrite --validate --dry-run="$dry_run" -f -

    # All namespaces to K8s
    oc process -f "$__dirname"/../openshift/authorize/networkSecurityPolicy/allNamespacesK8s.yml \
    NAMESPACE="$namespace" \
    | oc -n "$namespace" apply --wait --overwrite --validate --dry-run="$dry_run" -f -

    # Inter-namespace (dev->dev, test->test, prod->prod)
    oc process -f "$__dirname"/../openshift/authorize/networkSecurityPolicy/interNamespace.yml \
    SUFFIX="$suffix" \
    AIRFLOW_NAMESPACE="$airflow_namespace" \
    GGIRCS_NAMESPACE="$ggircs_namespace" \
    CIIP_NAMESPACE="$ciip_namespace" \
    | oc -n "$namespace" apply --wait --overwrite --validate --dry-run="$dry_run" -f -
  done
done
