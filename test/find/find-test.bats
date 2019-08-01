#!/usr/bin/env bats

@test "\$FIND contains the detected path to 'find'" {
  fixture="${BATS_TEST_DIRNAME}/find-test.mk"
  result="$(make -f "${fixture}" find.echo)"
  [ -n "$result" ]
}

@test "throws an error when 'find' is missing from the path" {
  orig_path="${PATH}"
  fixture_path="${BATS_TMPDIR}/cas-postgres/test/find/fixture_path"
  fixture="${BATS_TEST_DIRNAME}/find-test.mk"

  mkdir -p "${fixture_path}"
  rm -f "${fixture_path}/*"
  ln -sf "$(command -v make)" "${fixture_path}/make"
  PATH="${fixture_path}"

  run make -f "${fixture}" find.echo

  PATH="${orig_path}"

  [ "$status" -eq 2 ]
}
