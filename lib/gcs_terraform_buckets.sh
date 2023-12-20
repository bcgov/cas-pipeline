#!/bin/bash
set -euo pipefail

usage() {
    cat << EOF
$0 [OPTIONS]

Runs the GCP CLI to provision storage buckets for Terraform usage.

The list of namespaces affected by the script is defined by the
"--project-prefixes" and "--project-suffixes" options (see below).
For instance, "--project-prefixes abc123,456qwe --project-suffixes dev,test"
would affect the following namespaces: abc123-dev, abc123-test, 456qwe-dev and 456qwe-test

Options:

  -pp, --project-prefixes
    The comma-separated project prefixes of the project to create buckets for. e.g. "abc123,456qwe"
  -ps, --project-suffixes
    The comma-separated project suffixes of the project to create buckets for. Defaults to "dev,test,prod"
  -gcp, --google-cloud-project
    The google cloud project id where the buckets will be created.
  -gcr, --google-cloud-region
    The google cloud region where the buckets will be created. Defaults to "northamerica-northeast1", in Montreal.
  -h, --help
    Prints this message


EOF
}

# default options
declare -a suffixes=("dev" "test" "prod")
google_region="northamerica-northeast1" # Montreal

while [[ -n ${1+x} && "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -pp | --project-prefixes )
    shift
    IFS=',' read -r -a prefixes <<< "$1"
    ;;
  -ps | --project-suffixes )
    shift
    IFS=',' read -r -a suffixes <<< "$1"
    ;;
  -gcp | --google-cloud-project )
    shift
    google_project=$1
    ;;
  -gcr | --google-cloud-region )
    shift
    google_region=$1
    ;;
  -h | --help )
    usage
    exit 0
    ;;
esac; shift; done



for prefix in "${prefixes[@]}"; do
  for suffix in "${suffixes[@]}"; do

    namespace=$prefix-$suffix
    bucket="gs://${namespace}-state"
    echo "Creating TF state bucket $bucket for $namespace namespace"
    gcloud storage buckets create $bucket --project=$google_project --location=$google_region

  done
done

