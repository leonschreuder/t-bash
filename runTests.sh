#!/usr/bin/env bash

usage() {
cat << EOF
T-Bash   v0.3
A tiny bash testing framework.

Loads all files in the cwd that are prefixed with 'test_', and then executes
all functions that are prefixed with 'test_' in those files. Large tests are
prefixed with 'testLarge_' and are only executed with the -a flag.
Currently only supports 'assertEquals' test, all other cases can be tested
using simple if statements and the 'fail' method.

Usage:
-h                Print this help
-v                verbose
-a                Run all tests, including those prefixed with testLarge_
-t                Prints how long each test took
-m [testmatcher]  Runs only the tests that match the string (bash matches supported)
EOF
exit
}

main() {

  # adding : behind the command will require arguments
  while getopts "vhatm:" opt; do
    case $opt in
      h)
        usage
        ;;
      v)
        export VERBOSE=true
        ;;
      a)
        export RUN_LARGE_TESTS=true
        ;;
      t)
        export TIME_FUNCS=true
        ;;
      m)
        export MATCH="$OPTARG"
        ;;
      *)
        usage
        ;;
    esac
  done

  callEveryTest
}

callEveryTest() {
  TEST_FILE_COUNT=0
  FAILING_TESTS=0

  for test_file in ./test_*; do
    log "running $test_file"
    ((TEST_FILE_COUNT++))

    # Load the test files in a sub-shell, to prevent redefinition problems
    (
      source $test_file

      for currFunc in `compgen -A function`
      do
        if [[ $currFunc == "test_"* ]]; then
          callTest $currFunc
        elif [[ $RUN_LARGE_TESTS && $currFunc == "testLarge_"* ]]; then
          callTest $currFunc
        fi
      done

      # since we dont have access to the outer shell, let the return
      # code be the error count.
      exit $FAILING_TESTS_IN_FILE
    )

    failedTestReturned=$?
    if [[ $failedTestReturned > 0 ]]; then
      ((FAILING_TESTS+=$failedTestReturned))
    fi
  done

  if [[ $FAILING_TESTS > 0 ]]; then
    echo $FAILING_TESTS failing tests in $TEST_FILE_COUNT files
    echo TEST SUITE FAILED
    exit 1
  else
    echo suite successfull
  fi
}

# Helper functions

callIfExists() {
  declare -F -f $1 > /dev/null
  if [ $? == 0 ]; then
    $1
  fi
}

callTest() {
  testFunc=$1
  if [[ -z "$MATCH" || $testFunc == $MATCH ]]; then
    log "  $testFunc"

    callIfExists setup

    if [[ $TIME_FUNCS ]]; then
      echo
      echo "$testFunc"
      eval "time -p $testFunc"
    else
      eval $testFunc
    fi

    if [ $? != 0 ]; then
      ((FAILING_TESTS_IN_FILE++))
    fi
    callIfExists teardown
  fi
}

# allows specifyng the call-stack depth at which the error was thrown
failFromStackDepth() {
  printf "FAIL: $test_file(${BASH_LINENO[$1-1]}) > ${FUNCNAME[$1]}\n"
  printf "    $2\n"
  callIfExists teardown

  ((FAILING_TESTS_IN_FILE++))
}

log() {
  if [ $VERBOSE ]; then
    echo "$1"
  fi
}

# Asserts:
#--------------------------------------------------------------------------------

assertEquals() {
  if [[ $2 != $1 ]]; then
    maxSizeForMultiline=30
    if [[ "${#1}" -gt $maxSizeForMultiline || ${#2} -gt $maxSizeForMultiline ]]; then
      failFromStackDepth 2 "expected: '$1'\n    got:      '$2'"
    else
      failFromStackDepth 2 "expected '$1', got '$2'"
    fi
  fi
}

fail() {
  failFromStackDepth 2 "$1"
}


# Main entry point (excluded from tests)
if [[ "$0" == "$BASH_SOURCE" ]]; then
  main $@
fi
