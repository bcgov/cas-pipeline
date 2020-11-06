#!/bin/bash

set -euo pipefail

token=$GH_TOKEN
org=bcgov
team=cas-owners
project_prefix=0fad32
declare -a prefixes=("0fad32" "09269b" "9212c9")
declare -a suffixes=("tools" "dev" "test" "prod")

for login in $(curl --silent -H "Authorization: token $token" https://api.github.com/orgs/$org/teams/$team/members | jq -r '.[] | .login'); do
  for prefix in "${prefixes[@]}"; do
    for suffix in "${suffixes[@]}"; do
      namespace=$prefix-$suffix
      oc process -f openshift/authorize/rolebinding/admin.yml GH_LOGIN=$login NAMESPACE=$namespace | oc apply --wait --overwrite --validate -f-
    done
  done
done