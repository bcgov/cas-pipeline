#!/bin/bash
set -euo pipefail

usage() {
    cat << EOF
$0 [OPTIONS]

Creates a 'dockerhub-registry' secret in all namespaces defined by the prefix/suffix permutations.

The list of namespaces affected by the script is defined by the
"--project-prefixes" and "--project-suffixes" options (see below).
For instance, "--project-prefixes abc123,456qwe --project-suffixes dev,test"
would affect the following namespaces: abc123-dev, abc123-test, 456qwe-dev and 456qwe-test

Maintainer: Pierre Bastianelli <pierre.bastianelli@gov.bc.ca>

Options:

  -pp, --project-prefixes
    The comma-separated project prefixes where the secret will be added. e.g. "abc123,456qwe"
  -ps, --project-suffixes
    The comma-separated project suffixes where the secret will be added. Defaults to "dev,test,prod"
  -s, --docker-server
    The docker server to use. Defaults to "https://index.docker.io/v1/"
  -u, --docker-username
    The username to use for the docker registry
  -p, --docker-password
    The password to use for the docker registry
  -e, --docker-email
    The email to use for the docker registry
  --dry-run
    Prints the list affected things
  -h, --help
    Prints this message

EOF
}

# default options
dry_run="none"
docker_server="https://index.docker.io/v1/"
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
  -s | --docker-server )
    shift
    docker_server=$1
    ;;
  -u | --docker-username )
    shift
    docker_username=$1
    ;;
  -p | --docker-password )
    shift
    docker_password=$1
    ;;
  -e | --docker-email )
    shift
    docker_email=$1
    ;;
  --dry-run )
    dry_run="client"
    ;;
  -h | --help )
    usage
    exit 0
    ;;
esac; shift; done



for prefix in "${prefixes[@]}"; do
  for suffix in "${suffixes[@]}"; do
    namespace=$prefix-$suffix 
    echo "Creating dockerhub-registry secret in $namespace namespace"

    oc create secret docker-registry dockerhub-registry \
    -n "$namespace" \
    --docker-server="$docker_server" \
    --docker-username="$docker_username" \
    --docker-password="$docker_password" \
    --docker-email="$docker_email" \
    --dry-run="$dry_run"

  done
done
