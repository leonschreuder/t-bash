#!/usr/bin/env bash

SELF_UPDATE_URL="https://raw.githubusercontent.com/meonlol/t-bash/master/runTests.sh"

COLOR_NONE='\e[0m'
COLOR_RED='\e[0;31m'
COLOR_GREEN='\e[0;32m'

help() {
  cat << EOF
T-Bash   v1.0.0
A tiny self-updating testing framework for bash.

Loads all files in the cwd that are prefixed with 'test_', and then executes
all functions that are prefixed with 'test_' in those files. Slow/lage tests
should be prefixed with 'testLarge_' and are only run when providing the -a
flag.

Built-in matchers:
assertEquals "equality" "equality"        # all your basic comparison needs.
assertMatches "^ma.*ng$" "matching"       # I want to practice my regex
assertNotEquals "same" "equality"         # Anything but this.
assertNotMatches "^ma.*ng$" "equality"    # I know regex so well I'm sure this works. 
fail "msg"                                # I write my own damd checks, thank you!

Custom checks are easily built using if-statements and the fail function:

[[ ! -f ./my/marker.txt ]] && fail "Where did my file go?"

..but there are some more pre-built asserts in extended_matchers.sh.

For more detailed examples, see: https://github.com/meonlol/t-bash/examples

Usage:
./runTests.sh [-hvamtceu] [test_files...]

-h                Print this help
-v                What test prints what now?
-a                Run all tests, including those prefixed with testLarge_
-m [testmatcher]  Runs only the tests that match the string.
-t                Runs each test with 'time' command.
-c                Print pretty colors for easy diffing
-e                Extended diff. Diffs using 'wdiff' and/or 'colordiff' when installed.
-u                Execute a self-update (updates from master).
EOF
exit
}

# main (files and suite) {{{1

main() {
  while getopts "hvam:tceu" opt; do
    case $opt in
      h)
        help
        ;;
      v)
        export VERBOSE=true
        ;;
      a)
        export RUN_LARGE_TESTS=true
        ;;
      m)
        export MATCH="$OPTARG"
        ;;
      t)
        export TIMED=true
        ;;
      c)
        export COLOR_OUTPUT=true
        ;;
      e)
        export EXTENDED_DIFF=true
        ;;
      u)
        runSelfUpdate
        exit
        ;;
      *)
        help
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  declare -i TOTAL_FAILING_TESTS=0
  [[ "$TIMED" == "true" ]] && export VERBOSE=true # doesn't make sense to print time per test, but not the test name

  resolveTestFiles "$@"

  for test_file in ${TEST_FILES[@]}; do
    verboseEcho "running $test_file"

    # Load the test files in a sub-shell, to prevent overwriting functions
    # between files (primarily setup/teardown functions)
    (callTestsInFile $test_file)
    TOTAL_FAILING_TESTS+=$? # Will be 0 if no tests failed.
  done

  if [[ $TOTAL_FAILING_TESTS > 0 ]]; then
    echo $TOTAL_FAILING_TESTS failing tests in $TEST_FILE_COUNT files
    echo TEST SUITE FAILED
    exit 1
  else
    echo suite successfull
  fi
}

resolveTestFiles() {
  if [[ "$@" != "" ]]; then
    TEST_FILES=($@)
  else
    TEST_FILES=($(echo ./test_*))
  fi
  TEST_FILE_COUNT=${#TEST_FILES[@]}
}

# tests in file {{{1

callTestsInFile() {
  declare -i testCount=0 failingTestCount=0
  declare -i PRINTED_LINE_COUNT_AFTER_DOTS

  source $1
  checkHasTests
  tryCallForFile "fileSetup"
  initDotLine

  for currTestFunc in $(getTestFuncs); do
    testCount+=1 #increment the testCount each time, so we can use it to print progress dots
    updateDotLine
    verboseEcho "  $currTestFunc"

    # run the test, tee the output in a temp file, and capture the exit code of the first command
    local outFile="$(mktemp)"
    if [[ "$TIMED" == "true" ]]; then
      # the {time;} is so the output of the time command is piped to tee as well
      { time -p runTest $currTestFunc ; } 2>&1 | tee $outFile; exitCode=${PIPESTATUS[0]}
      echo # newline to separate tests for readability of time
    else
      runTest $currTestFunc 2>&1 | tee $outFile; exitCode=${PIPESTATUS[0]}
    fi

    if [[ $exitCode -ne 0 ]]; then
      failingTestCount+=1
      [[ "$(cat $outFile)" == "" ]] &&
        failFromStackDepth "$currTestFunc" "Test failed without printing anything." | tee $outFile # tee also catches the exitWithError, so we continue with the file
    fi

    countLinesMoved "$(cat $outFile)"
  done

  tryCallForFile "fileTeardown"

  # since we want to be able to use echo in the tests, but are also in a
  # sub-shell so we can't set variables, we use the exit-code to return the
  # number of failing tests.
  exit $failingTestCount
}

getTestFuncs() {
  for currFunc in $(compgen -A function); do
    if [[ $currFunc == "test_"* || $currFunc == "testLarge_"* ]]; then #only consider test functions
      if [[ -n ${MATCH+x} ]]; then
        # when in matching mode, ignore other params
        if [[ $currFunc =~ $MATCH ]]; then
          echo "$currFunc"
        fi
      else
        if [[ "$RUN_LARGE_TESTS" == "true" || $currFunc == "test_"* ]]; then
          echo "$currFunc"
        fi
      fi
    fi
  done
}

checkHasTests() {
  funcs="$(getTestFuncs)"
  if [[ "$funcs" == "" || "$(echo "$funcs" | wc -l )" -lt 1 ]]; then
    echo "no tests found"
    exit 0
  fi
}

runTest() {
  callIfExists setup
  trap 'callIfExists teardown' EXIT # set a trap to call teardown in case an exception is thrown
  $1
  trap - EXIT # Exited normally, so we can remove the trap
  callIfExists teardown
}

callIfExists() {
  if funcExists "$1"; then
    $1
  fi
}

tryCallForFile() {
  if funcExists "$1"; then
    verboseEcho "  $1"
    $1
    [[ $? != 0 ]] && echo "FAIL: $1 failed." && exit $(getTestFuncs | wc -l)
  fi
}

# Dot Line {{{1

# We have to do some magic to print a dot for every test, but still print any test output correctly.
initDotLine() {
  if [[ "$VERBOSE" != true ]]; then
    echo "" # start with a blank line onto which we can print the dots.
    # Tracks how many lines have been printed since the dot-line, so we know how many lines we have to go up to print more dots.
    PRINTED_LINE_COUNT_AFTER_DOTS+=1
  fi
}

# Add a dot to the dot line, and jump back down to where we where
updateDotLine() {
  if [[ "$VERBOSE" != true ]]; then
    tput cuu $PRINTED_LINE_COUNT_AFTER_DOTS # move the cursor up to the dot-line
    echo -ne "\r" # go to the start of the line
    printf "%0.s." $(seq 1 $testCount) # print a dot for every test that has run, overwriting previous dots
    tput cud $PRINTED_LINE_COUNT_AFTER_DOTS # move the cursor back down to where we where
    echo -ne "\r" # The cursor still has the horisontal position of the last dot. So go to the start of the line.
  fi
}

countLinesMoved() {
  TEST_LINE_COUNT=$(echo -e "$@" | wc -l)
  [[ -n $@ ]] && PRINTED_LINE_COUNT_AFTER_DOTS+=$TEST_LINE_COUNT
}

# Failing {{{1

# allows specifyng the call-stack depth at which the error was thrown
failFromStackDepth() {
  # if the supplied stack depth isn't a number, assume it is the function name.
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    lineNr="${BASH_LINENO[$1-1]}";
    funcName=${FUNCNAME[$1]}
  else
    lineNr="?"
    funcName="$1"
  fi
  echo "FAIL: $test_file($lineNr) > $funcName"
  shift
  echo -e "$@" | sed 's/^/    /'

  exit 1
}

# Output {{{1

failWithExtendedDiff() {
  if [[ "$EXTENDED_DIFF" == "true" ]]; then
    if hash wdiff 2>/dev/null; then
      if hash colordiff; then
        failFromStackDepth 3 "$(wdiff <(echo "$1") <(echo "$2") | colordiff)"
      else
        failFromStackDepth 3 "$(wdiff <(echo "$1") <(echo "$2"))"
      fi
    else
      exitWithError "No extended diff-tool found. Supports 'wdiff' with optional 'colordiff'."
    fi
    echo
  else
    failFromStackDepth 3 "$(formatAValueBValue "expected:" "$1" "got:" "$2" "$3")"
  fi
}

formatAValueBValue() {
  # when failing on equals, different lenths of output are printed differently.
  maxSizeForInline=30
  a="$1"
  valueA="$(echo "$2" | cat -v)" # cat -v to print non-printing characters
  b="$3"
  valueB="$(echo "$4" | cat -v)"

  if [[ "$COLOR_OUTPUT" == "true" ]]; then
    valueA="$COLOR_GREEN$valueA$COLOR_NONE"
    valueB="$COLOR_RED$valueB$COLOR_NONE"
  fi

  if [[ "$(echo "$valueA" | wc -l)" -gt 1 || "$(echo "$valueB" | wc -l)" -gt 1 ]]; then
    # output has multiple lines
    echo "> $a"
    echo "$valueA"
    echo "> $b" #
    echo "$valueB"
  elif [[ "${#valueA}" -gt $maxSizeForInline || ${#valueB} -gt $maxSizeForInline ]]; then
    # output has long lines
    width=$(getWithOfWidestString "$a" "$b")
    alighnedA="$(rightAlign $width "$a")"
    alighnedB="$(rightAlign $width "$b")"
    echo "$alighnedA '$valueA'" # So much output we should print on seperate lines. Print 2 lines and indent 'got:'
    echo "$alighnedB '$valueB'" # So much output we should print on seperate lines. Print 2 lines and indent 'got:'
  else
    # output has short lines
    echo "$a '$valueA', $b '$valueB'" # Not so much output. Print all in one line, comma separated
  fi

  if [[ -n ${5+x} ]]; then
    echo "$5"
  fi
}

# Helpers {{{1

funcExists() {
  declare -F -f $1 > /dev/null
}

getWithOfWidestString() {
    [[ ${#1} -gt ${#2} ]] && echo ${#1} || echo ${#2}
}

rightAlign() {
  declare -i leftIndent=$1-${#2}
  [[ $leftIndent -gt 0 ]] && printf " %.0s" $(seq 1 $leftIndent)
  echo $2
}

verboseEcho() {
  [[ "$VERBOSE" == true ]] && echo "$1"
}

exitWithError() {
  >&2 echo -e "ERROR: $@"
  exit 1
}

# Self update {{{1

runSelfUpdate() {
  # Tnx: https://stackoverflow.com/q/8595751/3968618
  echo "Performing self-update..."

  echo "Downloading latest version..."
  curl $SELF_UPDATE_URL -o $0.tmp
  if [[ $? != 0 ]]; then
    exitWithError "Update failed: Error downloading."
  fi

  # Copy over modes from old version
  filePermissions=$(stat -c '%a' $0 2> /dev/null)
  if [[ $? != 0 ]]; then
    filePermissions=$(stat -f '%A' $0)
  fi
  if ! chmod $filePermissions "$0.tmp" ; then
    exitWithError "Update failed: Error setting access-rights on $0.tmp"
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

# Asserts {{{1

assertEquals() {
  [[ "$2" != "$1" ]] &&
    failWithExtendedDiff "$1" "$2" "$3"
}

assertNotEquals() {
  [[ "$2" == "$1" ]] &&
    failFromStackDepth 2 "$(formatAValueBValue "expected:" "$1" "to not equal:" "$2" "$3")"
}

assertMatches() {
  [[ ! "$2" =~ $1 ]] &&
    failFromStackDepth 2 "$(formatAValueBValue "expected regex:" "$1" "to match:" "$2" "$3")"
}

assertNotMatches() {
  [[ "$2" =~ $1 ]] &&
    failFromStackDepth 2 "$(formatAValueBValue "expected regex:" "$1" "to NOT match:" "$2" "$3")"
}

fail() {
  failFromStackDepth 2 "$1"
}

# Main {{{1
# Main entry point (excluded from tests)
if [[ "$0" == "$BASH_SOURCE" ]]; then
  main $@
fi
# vim:fdm=marker
