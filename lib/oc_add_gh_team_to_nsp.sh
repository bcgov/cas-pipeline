#!/bin/bash
set -euo pipefail

usage() {
    cat << EOF
$0 [OPTIONS]

Retrieves the list of users from a GitHub team
and adds a RoleBinding for each user in the provided namespace sets

The list of namespaces affected by the script is defined by the
"--project-prefixes" and "--project-suffixes" options (see below).
For instance, "--project-prefixes abc123,456qwe --project-suffixes tools,dev"
would affect the following namespaces: abc123-tools, abc123-dev, 456qwe-tools and 456qwe-dev

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

response=$(curl -X POST https://api.github.com/graphql \
-H "Authorization: Bearer $token" \
-H "Content-Type: application/json" \
-d "{
    \"query\": \"query { organization(login: \"${org}\") { team(slug: \"${team}\") { members(first: 100) { edges { node { login } } } } } }\"
}")

#response=$(curl --silent -H "Authorization: token $token" https://api.github.com/orgs/"$org"/teams/"$team"/members)
echo "GitHub API response: $response"
team_members=$(echo "$response" | jq -r '.[] | .login | ascii_downcase')
echo "Found the following members"
# Extract your GitHub username
my_github_username=$(oc whoami | awk -F'@' '{print $1}')

for prefix in "${prefixes[@]}"; do
  for suffix in "${suffixes[@]}"; do
    namespace=$prefix-$suffix
    if ! $dry_run; then
      echo "first if"
      # Temporarily change the GH_TEAM of the user calling this script so that their permissions are not removed in the following command
      #oc process -f "$__dirname"/clusterRoleBinding.yaml GH_LOGIN="$my_github_username" GH_TEAM="temp_admin" NAMESPACE="$namespace" ROLE="$role" | \
      #  oc -n "$namespace" apply --wait --overwrite --validate -f-
      # Remove rolebindings from namespace
      #oc -n "$namespace" delete rolebinding -l created-by=cas-pipeline,gh-team="${org}_$team"
    fi
    for login in $team_members; do
      echo "Binding GitHub user $login to role $role in $namespace"
      if ! $dry_run; then
        echo "second if"
        # Add namespace permissions for members in the specified GH teams
        #oc process -f "$__dirname"/clusterRoleBinding.yaml GH_LOGIN="$login" GH_TEAM="${org}_$team" NAMESPACE="$namespace" ROLE="$role" | \
        #oc -n "$namespace" apply --wait --overwrite --validate -f-
      fi
    done
  done
done
