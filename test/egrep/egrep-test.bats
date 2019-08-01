#!/usr/bin/env bats

@test "\$EGREP contains the detected path to 'egrep'" {
  fixture="${BATS_TEST_DIRNAME}/egrep-test.mk"
  result="$(make -f "${fixture}" egrep.echo)"
  [ -n "$result" ]
}

@test "throws an error when 'egrep' is missing from the path" {
  orig_path="${PATH}"
  fixture_path="${BATS_TMPDIR}/cas-postgres/test/egrep/fixture_path"
  fixture="${BATS_TEST_DIRNAME}/egrep-test.mk"

  mkdir -p "${fixture_path}"
  rm -f "${fixture_path}/*"
  ln -sf "$(command -v make)" "${fixture_path}/make"
  PATH="${fixture_path}"

  run make -f "${fixture}" egrep.echo

  PATH="${orig_path}"

  [ "$status" -eq 2 ]
}
