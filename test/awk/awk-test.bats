#!/usr/bin/env bats

@test "\$AWK contains the detected path to 'awk'" {
  fixture="${BATS_TEST_DIRNAME}/awk-test.mk"
  result="$(make -f "${fixture}" awk.echo)"
  [ -n "$result" ]
}

@test "throws an error when 'awk' is missing from the path" {
  orig_path="${PATH}"
  fixture_path="${BATS_TMPDIR}/cas-postgres/test/awk/fixture_path"
  fixture="${BATS_TEST_DIRNAME}/awk-test.mk"

  mkdir -p "${fixture_path}"
  rm -f "${fixture_path}/*"
  ln -sf "$(command -v make)" "${fixture_path}/make"
  PATH="${fixture_path}"

  run make -f "${fixture}" awk.echo

  PATH="${orig_path}"

  [ "$status" -eq 2 ]
}
