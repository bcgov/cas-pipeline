#!/usr/bin/env bats

setup () {
  fixture_path="${BATS_TMPDIR}/cas-postgres/test/git"
  mkdir -p "${fixture_path}"
  pushd "${fixture_path}" || exit 1
  rm -rf "${fixture_path}/.git"
  git init
  git checkout -b feature/unicorn
  git commit --allow-empty -m 'empty'
}

@test "\$GIT contains the detected path to 'git'" {
  fixture="${BATS_TEST_DIRNAME}/git-test.mk"
  result="$(make -f "${fixture}" git.echo)"
  [ -n "$result" ]
}

@test "thows an error when 'git' is missing from the path" {
  orig_path="${PATH}"
  fixture_path="${BATS_TMPDIR}/cas-postgres/test/git/fixture_path"
  fixture="${BATS_TEST_DIRNAME}/git-test.mk"

  mkdir -p "${fixture_path}"
  rm -f "${fixture_path}/*"
  ln -sf "$(command -v make)" "${fixture_path}/make"
  PATH="${fixture_path}"

  run make -f "${fixture}" git.echo

  PATH="${orig_path}"

  [ "$status" -eq 2 ]
}

@test "\$GIT_SHA1 contains a revision hash" {
  fixture="${BATS_TEST_DIRNAME}/git-test.mk"
  result="$(make -f "${fixture}" git_sha1.echo)"
  [ -n "$result" ]
}

@test "\$GIT_BRANCH contains the branch name" {
  fixture="${BATS_TEST_DIRNAME}/git-test.mk"
  result="$(make -f "${fixture}" -s git_branch.echo)"
  [ "$result" == "feature/unicorn" ]
}

@test "\$GIT_BRANCH_NORM contains the normalized branch name for openshift" {
  fixture="${BATS_TEST_DIRNAME}/git-test.mk"
  result="$(make -f "${fixture}" -s git_branch_norm.echo)"
  [ "$result" == "feature-unicorn" ]
}

teardown () {
  fixture_path="${BATS_TMPDIR}/cas-postgres/test/git"
  rm -rf "${fixture_path}"
  popd || exit 1
}
