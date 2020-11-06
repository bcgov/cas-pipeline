#!/bin/bash
set -euo pipefail

usage() {
    cat << EOF
$0 [OPTIONS]

Retrieves the list of users from a GitHub team 
and adds a RoleBinding for each user in the provided namespace sets

Maintainer: Matthieu Foucault <matthieu@button.is>

Options:

  --token
    The GitHub personal access token used to access the GitHub team members list.
    The token needs read access to orgs. Go to https://github.com/settings/tokens to create a token.
  -o, --org
    The GitHub organisation in which the team is located. Defaults to bcgov.
  -t, --team
    The GitHub team
  -pp, --project-prefixes
    The comma-separated project prefixes where the team members will be added. e.g. "abc123,456qwe"
  -ps, --project-suffixes
    The comma-separated project suffixes where the team members will be added. Defaults to "tools,dev,test,prod"
  -r, --role
    The cluster role the users will be bound to. e.g. "admin", "edit" or "view"
  --dry-run
    Prints the list of roles bindings that would be created without applying the changes
  -h, --help
    Prints this message

EOF
}

# default options
org=bcgov
dry_run=false
declare -a suffixes=("tools" "dev" "test" "prod")

while [[ -n ${1+x} && "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  --token )
    shift
    token=$1
    ;;
  -t | --team )
    shift
    team=$1
    ;;
  -o | --org)
    shift
    org=$1
    ;;
  -pp | --project-prefixes )
    shift
    IFS=',' read -r -a prefixes <<< "$1"
    ;;
  -ps | --project-suffixes )
    shift
    IFS=',' read -r -a suffixes <<< "$1"
    ;;
  -r | --role )
    shift
    role=$1
    ;;
  --dry-run )
    dry_run=true
    ;;
  -h | --help )
    usage
    exit 0
    ;;
esac; shift; done

__dirname="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "Retriving members of $org/$team"

for login in $(curl --silent -H "Authorization: token $token" https://api.github.com/orgs/"$org"/teams/"$team"/members | jq -r '.[] | .login | ascii_downcase'); do
  for prefix in "${prefixes[@]}"; do
    for suffix in "${suffixes[@]}"; do
      namespace=$prefix-$suffix
      echo "Binding GitHub user $login to role $role in $namespace"
      if ! $dry_run; then
        oc process -f "$__dirname"/../openshift/authorize/rolebinding/clusterRoleBinding.yml GH_LOGIN="$login" NAMESPACE="$namespace" ROLE="$role" | \
        oc apply --wait --overwrite --validate -f-
      fi
    done
  done
done