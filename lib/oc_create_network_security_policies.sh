#!/bin/bash
set -euo pipefail

usage() {
    cat << EOF
$0 [OPTIONS]

Creates the most basic NetworkSecurityPolicies required by our architecture.

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

    # Deployer role -> K8s API
    oc process -f "$__dirname"/../openshift/authorize/networkSecurityPolicy/deployerRoleK8s.yml \
    NAMESPACE="$namespace" \
    | oc -n "$namespace" apply --wait --overwrite --validate --dry-run="$dry_run" -f -
  done
done
