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
    The comma-separated project prefixes to create tfbackend files for. e.g. "abc123,456qwe"
  -ps, --project-suffixes
    The comma-separated project suffixes to create tfbackend files for. Defaults to "dev,test,prod"
  -gcp, --google-cloud-region
    The google cloud region where the buckets are located. Defaults to "northamerica-northeast1", in Montreal.
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
  -gcr | --google-cloud-region )
    shift
    google_region=$1
    ;;
  -h | --help )
    usage
    exit 0
    ;;
esac; shift; done

mkdir -p ./terraform/namespace-backends

for prefix in "${prefixes[@]}"; do
  for suffix in "${suffixes[@]}"; do

    namespace=$prefix-$suffix
    bucket="${namespace}-state"

		# Note: Due to how `<<-` Heredoc works, the following must use tab indentation
		cat <<-EOF > ./terraform/namespace-backends/$namespace.gcs.tfbackend
		bucket = "$bucket"
		prefix = "terraform/state"
		credentials = "/etc/gcp/credentials.json"
		EOF

  done
done
