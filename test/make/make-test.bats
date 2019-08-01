#!/usr/bin/env bats

@test "\$make_this_makefile contains the detected path to the current makefile" {
  skip
  fixture="${BATS_TEST_DIRNAME}/make-test.mk"
  result="$(make -f "${fixture}" make_this_makefile.echo)"
  [ "$result" == "untested" ]
}

@test "\$make_other_makefile contains the detected path to other included makefiles" {
  skip
  fixture="${BATS_TEST_DIRNAME}/make-test.mk"
  result="$(make -f "${fixture}" make_other_makefile.echo)"
  [ "$result" == "untested" ]
}

@test "\$make_parent_makefile contains the detected path to the parent makefile" {
  skip
  fixture="${BATS_TEST_DIRNAME}/make-test.mk"
  result="$(make -f "${fixture}" make_parent_makefile.echo)"
  [ "$result" == "untested" ]
}

@test "\$make_need_help is blank when the target name is not 'help'" {
  fixture="${BATS_TEST_DIRNAME}/make-test.mk"
  run make -f "${fixture}" -s make_need_help.echo
  # echo "# lines[0]: '${lines[0]}'" >&3
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "" ]
}

@test "\$make_need_help is 'help' when the target name is 'help'" {
  fixture="${BATS_TEST_DIRNAME}/make-test.mk"
  run make -f "${fixture}" -s help
  # echo "# lines[0]: '${lines[0]}'" >&3
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "help" ]
}

@test "\$call make_help,one,two outputs the warning 'one -- two'" {
  skip
  fixture="${BATS_TEST_DIRNAME}/make-test.mk"
  run make -f "${fixture}" -s make_help.call
  [ "$status" -eq 0 ]
  [ "$output" = "one -- two" ]
}
