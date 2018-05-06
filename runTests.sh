#!/usr/bin/env bash

SELF_UPDATE_URL="https://raw.githubusercontent.com/meonlol/t-bash/master/runTests.sh"

usage() {
cat << EOF
T-Bash   v0.4.1
A tiny bash testing framework.

Loads all files in the cwd that are prefixed with 'test_', and then executes
all functions that are prefixed with 'test_' in those files. Large tests are
prefixed with 'testLarge_' and are only executed with the -a flag.
Currently only supports 'assertEquals' test, all other cases can be tested
using simple if statements and the 'fail' method.

Usage:
./runTests.sh [-hvatm] [test_files...]

-h                Print this help
-v                verbose
-a                Run all tests, including those prefixed with testLarge_
-t                Prints how long each test took
-m [testmatcher]  Runs only the tests that match the string (bash matches supported)
-u                Execute a self-update
EOF
exit
}

main() {

  # adding : behind the command will require arguments
  while getopts "vhatm:u" opt; do
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
        export TIMED=true
        ;;
      m)
        export MATCH="$OPTARG"
        ;;
      u)
        runSelfUpdate
        exit
        ;;
      *)
        usage
        ;;
    esac
  done

  shift "$((OPTIND - 1))"
  if [[ "$@" != "" ]]; then
    TEST_FILES=($@)
  else
    TEST_FILES=($(echo ./test_*))
  fi

  TEST_FILE_COUNT=${#TEST_FILES[@]}
  FAILING_TESTS=0

  for test_file in ${TEST_FILES[@]}; do
    logv "running $test_file"

    # Load the test files in a sub-shell, to prevent overwriting functions
    # between files (mainly setup & teardown)
    (callTestsInFile $test_file)
    ((FAILING_TESTS+=$?)) # Will be 0 if no tests failed.
  done

  if [[ $FAILING_TESTS > 0 ]]; then
    echo $FAILING_TESTS failing tests in $TEST_FILE_COUNT files
    echo TEST SUITE FAILED
    exit 1
  else
    echo suite successfull
  fi
}

callTestsInFile() {
  source $1

  testCount=0
  [[ ! $VERBOSE ]] && initDotLine

  for currFunc in $(compgen -A function); do
    callFuncIfTest $currFunc
  done

  # since we want to be able to use echo in the tests, but are also in a
  # sub-shell so we can't set variables, we use the exit-code to return the
  # number of failing tests.
  exit $FAILING_TEST_COUNT
}

# Calls supplied function if it is a test, but also counts + handles test output
callFuncIfTest() {
  currFunc="$1"
  if [[ $currFunc == "test_"* || $RUN_LARGE_TESTS && $currFunc == "testLarge_"* ]] &&
    [[ -z ${MATCH+x} || $currFunc == $MATCH ]]; then

    local output
    ((testCount+=1))
    [[ ! $VERBOSE ]] && updateDotLine

    output=$(callTest $currFunc 2>&1)

    ((FAILING_TEST_COUNT+=$?))

    if [[ -n $output ]]; then
      (( _PRINTED_LINE_COUNT+=$(echo -e "$output" | wc -l) ))
      echo -e "$output"
    fi
  fi
}

# We have to do some magic to print a dot for every test, but still print any test output correctly.
initDotLine() {
  echo "" # start with a blank line onto which we can print the dots.
  _PRINTED_LINE_COUNT=1 # Tracks how many lines have been printed since the dot-line, so we know how many lines we have to go up to print more dots.
}

# Add a dot to the dot line, and jump back down to where we where
updateDotLine() {
  tput cuu $_PRINTED_LINE_COUNT # move the cursor up to the dot-line
  echo -ne "\r" # go to the start of the line
  printf "%0.s." $(seq 1 $testCount) # print a dot for every test that has run, overwriting previous dots
  tput cud $_PRINTED_LINE_COUNT # move the cursor back down to where we where
  echo -ne "\r" # The cursor still has the horisontal position of the last dot. So go to the start of the line.
}

callTest() {
  testFunc="$1"
  logv "  $testFunc"

  callIfExists setup

  if [[ "$TIMED" == "true" ]]; then
    [[ "$VERBOSE" != "true" ]] && echo "$testFunc"
    eval "time -p $testFunc"
    echo
  else
    eval $testFunc
  fi

  callIfExists teardown
}

callIfExists() {
  declare -F -f $1 > /dev/null
  if [ $? == 0 ]; then
    $1
  fi
}

failUnexpected() {
    maxSizeForMultiline=30
    if [[ "${#1}" -gt $maxSizeForMultiline || ${#2} -gt $maxSizeForMultiline ]]; then
      failFromStackDepth 3 "expected: '$1'\n    got:      '$2'"
    else
      failFromStackDepth 3 "expected: '$1', got: '$2'"
    fi
}

# allows specifyng the call-stack depth at which the error was thrown
failFromStackDepth() {
  printf "FAIL: $test_file(${BASH_LINENO[$1-1]}) > ${FUNCNAME[$1]}\n"
  printf "    $2\n"
  callIfExists teardown

  exit 1
}

logv() {
  if [ $VERBOSE ]; then
    echo "$1"
  fi
}

runSelfUpdate() {
  # Tnx: https://stackoverflow.com/q/8595751/3968618
  echo "Performing self-update..."

  echo "Downloading latest version..."
  curl $SELF_UPDATE_URL -o $0.tmp
  if [[ $? != 0 ]]; then
    >&2 echo "Update failed: Error downloading."
    exit 1
  fi

  # Copy over modes from old version
  filePermissions=$(stat -c '%a' $0 2> /dev/null)
  if [[ $? != 0 ]]; then
    filePermissions=$(stat -f '%A' $0)
  fi
  if ! chmod $filePermissions "$0.tmp" ; then
    >&2 echo "Update failed: Error setting access-rights on $0.tmp"
    exit 1
  fi

  cat > selfUpdateScript.sh << EOF
#!/usr/bin/env bash
# Overwrite script with updated version
if mv "$0.tmp" "$0"; then
  echo "Done."
  rm \$0
  echo "Update complete."
else
  echo "Failed to overwrite script with updated version!"
fi
EOF

  echo -n "Overwriting old version..."
  exec /bin/bash selfUpdateScript.sh
}

# Asserts:
#--------------------------------------------------------------------------------

assertEquals() {
  if [[ "$2" != "$1" ]]; then
    failUnexpected "$1" "$2"
  fi
}

assertMatches() {
  if [[ "$2" != $1 ]]; then
    failUnexpected "$1" "$2"
  fi
}

fail() {
  failFromStackDepth 2 "$1"
}


# Main entry point (excluded from tests)
if [[ "$0" == "$BASH_SOURCE" ]]; then
  main $@
fi
