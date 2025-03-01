#!/usr/bin/env bash
set -uo pipefail

SCRIPT_VERSION="1.3.9"

SELF_UPDATE_URL="https://raw.githubusercontent.com/leonschreuder/t-bash/master/runTests.sh"

COLOR_NONE='\e[0m'
COLOR_RED='\e[0;31m'
COLOR_GREEN='\e[0;32m'

VERBOSE=false
T_QUIET=false
MATCH=""
RUN_LARGE_TESTS=false
TIMED=false
COLOR_OUTPUT=false
EXTENDED_DIFF=false
HIGHLIGHT_WHITESPACE=false

help() {
  cat << EOF
T-Bash   v$SCRIPT_VERSION
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

For more detailed examples, see: https://github.com/leonschreuder/t-bash/tree/master/examples

Usage:
./runTests.sh [-hvamtceu] [test_files...]

-h                Print this help
-v                What test prints what now?
-a                Run all tests, including those prefixed with testLarge_
-m [testmatcher]  Runs only the tests that match the string.
-t                Runs each test with 'time' command.
-c                Print pretty colors for easy diffing
-w                Highlight whitespace types in diff
-e                Extended diff. Diffs using 'wdiff' and/or 'colordiff' when installed.
-u                Execute a self-update (updates from master).
EOF
exit
}

# main (files and suite) {{{1

main() {
  while getopts "hvqam:tcewu" opt; do
    case $opt in
      h)
        help
        ;;
      v)
        export VERBOSE=true
        ;;
      q)
        export T_QUIET=true
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
      w)
        export HIGHLIGHT_WHITESPACE=true
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
  unset OPTIND # make sure this doesn't get inherited into the tests

  TOTAL_FAILING_TESTS=0
  if [ "$TIMED" = "true" ]; then export VERBOSE=true; fi # doesn't make sense to print time per test, but not the test name
  if ! tty -s; then export VERBOSE=true; fi # if there is no terminal, don't print using updating lines

  if [ "$T_QUIET" = true ]; then echo "Running tests quietly..."; fi

  resolveTestFiles "$@"

  for test_file in "${TEST_FILES[@]}"; do
    verboseEcho "running $test_file"

    # Load the test files in a sub-shell, to prevent overwriting functions
    # between files (primarily setup/teardown functions)
    (callTestsInFile "$test_file")
    TOTAL_FAILING_TESTS=$(( TOTAL_FAILING_TESTS+=$? )) # Will be 0 if no tests failed.
  done

  if [ $TOTAL_FAILING_TESTS -gt 0 ]; then
    echo "$TOTAL_FAILING_TESTS failing tests in $TEST_FILE_COUNT files"
    echo "TEST SUITE FAILED"
    exit 1
  else
    echo "suite successfull"
  fi
}

resolveTestFiles() {
  if [ "$*" != "" ]; then
    TEST_FILES=("$@")
  else
    TEST_FILES=($(echo ./test_*))
  fi
  TEST_FILE_COUNT=${#TEST_FILES[@]}
}

# tests in file {{{1

callTestsInFile() {
  testDots=""
  declare -i testCount=0 failingTestCount=0
  declare -i PRINTED_LINE_COUNT_AFTER_DOTS=0

  #shellcheck disable=1090
  source "$1"
  checkHasTests
  tryCallForFile "fileSetup"
  initDotLine

  for currTestFunc in $(getTestFuncs); do
    testDots+="."
    testCount+=1 #increment the testCount each time, so we can use it to print progress dots
    updateDotLine "$PRINTED_LINE_COUNT_AFTER_DOTS" "$testDots"
    verboseEcho "  $currTestFunc"

    # run the test, tee the output in a temp file, and capture the exit code of the first command
    local outFile
    outFile="$(mktemp)"
    if [ "$TIMED" = "true" ]; then
      # the {time;} is so the output of the time command is piped to tee as well
      { time -p runTest "$currTestFunc" ; } 2>&1 | tee "$outFile"; exitCode=${PIPESTATUS[0]}
      echo # newline to separate tests for readability of time
    else
      runTest "$currTestFunc" 2>&1 | tee "$outFile"; exitCode=${PIPESTATUS[0]}
    fi

    if [ "$exitCode" -ne 0 ]; then
      failingTestCount+=1
      if [ "$(cat "$outFile")" = "" ]; then
        failFromStackDepth "$currTestFunc" "Test failed without printing anything." | tee "$outFile" # tee also catches the exitWithError, so we continue with the file
      fi
    fi

    countLinesMoved "$(cat "$outFile")"
  done

  tryCallForFile "fileTeardown"

  # since we want to be able to use echo in the tests, but are also in a
  # sub-shell so we can't set variables, we use the exit-code to return the
  # number of failing tests.
  exit $failingTestCount
}

getTestFuncs() {
  if [ "$MATCH" != "" ]; then
    set | grep '^test\(Large\)\?_[a-zA-Z0-9_]\+\s\+()' | grepFunctionName | grep "$MATCH"
  elif [ "$RUN_LARGE_TESTS" = "true" ]; then
    set | grep '^test\(Large\)\?_[a-zA-Z0-9_]\+\s\+()' | grepFunctionName
  else
    set | grep '^test_[a-zA-Z0-9_]\+\s\+()' | grepFunctionName
  fi
}

grepFunctionName() {
  grep -o '^[a-zA-Z_][a-zA-Z0-9_]\+'
}

checkHasTests() {
  if [ "$(getTestFuncs | wc -l)" -lt 1 ]; then
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
    if ! $1 ;then
      echo "FAIL: $1 failed."
      exit "$(getTestFuncs | wc -l)"
    fi
  fi
}

# Dot Line {{{1

# We have to do some magic to print a dot for every test, but still print any test output correctly.
initDotLine() {
  if [ "$VERBOSE" != true ] && [ "$T_QUIET" != true ]; then
    echo "" # start with a blank line onto which we can print the dots.
    # Tracks how many lines have been printed since the dot-line, so we know how many lines we have to go up to print more dots.
    PRINTED_LINE_COUNT_AFTER_DOTS+=1
  fi
}

# Add a dot to the dot line, and jump back down to where we where
updateDotLine() {
  linesUpToDotLine="$1"
  dotsString="$2"
  if [ "$VERBOSE" != true ] && [ "$T_QUIET" != true ]; then
    tput cuu "$linesUpToDotLine" # move the cursor up to the dot-line
    echo -ne "\r" # go to the start of the line
    echo -n "$dotsString" # print a dot for every test that has run, overwriting previous dots
    tput cud "$linesUpToDotLine" # move the cursor back down to where we where
    echo -ne "\r" # The cursor still has the horisontal position of the last dot. So go to the start of the line.
  fi
}

countLinesMoved() {
  TEST_LINE_COUNT=$(echo -e "$@" | wc -l)
  if [ -n "$*" ]; then PRINTED_LINE_COUNT_AFTER_DOTS+=$TEST_LINE_COUNT; fi
}

countLinesMoved2() {
  file="$1"
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

formatAValueBValue() {
  # when failing on equals, different lenths of output are printed differently.
  maxSizeForInline=30
  nameA="$1"
  valueA="$2"
  nameB="$3"
  valueB="$4"
  msg=""
  if [ "$#" -gt 4 ]; then msg="$5"; fi

  if [[ "$HIGHLIGHT_WHITESPACE" == "true" ]]; then
    valueA="$(sed -e 's/\ /·/g' -e $'s/\t/▸ /g' -e 's/$/¬/' <<< "$valueA")"
    valueB="$(sed -e 's/\ /·/g' -e $'s/\t/▸ /g' -e 's/$/¬/' <<< "$valueB")"
  fi

  if [ "$msg" != "" ]; then echo "$msg"; fi

  if [[ "$EXTENDED_DIFF" == "true" ]]; then
    printExtendedDiff "$valueA" "$valueB"
  else

    if [[ "$COLOR_OUTPUT" == "true" ]]; then
      valueA="$COLOR_GREEN$valueA$COLOR_NONE"
      valueB="$COLOR_RED$valueB$COLOR_NONE"
    fi

    if [[ "$(echo "$valueA" | wc -l)" -gt 1 || "$(echo "$valueB" | wc -l)" -gt 1 ]]; then
      # output has multiple lines
      echo "> $nameA"
      echo "$valueA"
      echo "> $nameB"
      echo "$valueB"
    elif [[ "${#valueA}" -gt $maxSizeForInline || ${#valueB} -gt $maxSizeForInline ]]; then
      # Not multiline, but enough output we should print values on seperate
      # lines. Indent to make visualy comparing easyer.
      width=$(getWithOfWidestString "$nameA" "$nameB")
      echo "$(rightAlign "$width" "$nameA") '$valueA'"
      echo "$(rightAlign "$width" "$nameB") '$valueB'"
    else
      # Output is really short. So we can print inlined
      echo "$nameA '$valueA', $nameB '$valueB'" # Not so much output. Print all in one line, comma separated
    fi
  fi
}

printExtendedDiff() {
  if hash wdiff 2>/dev/null; then
    if hash colordiff; then
      wdiff -n <(echo "$1") <(echo "$2") | colordiff
    else
      wdiff <(echo "$1") <(echo "$2")
    fi
  else
    exitWithError "No extended diff-tool found. Supports 'wdiff' with optional 'colordiff'."
  fi
}

# Helpers {{{1

funcExists() {
  declare -F -f "$1" > /dev/null
}

getWithOfWidestString() {
  if [ ${#1} -gt ${#2} ]; then
    echo ${#1}
  else
    echo ${#2}
  fi
}

rightAlign() {
  declare -i leftIndent=$1-${#2}
  if [ $leftIndent -gt 0 ]; then
    printf " %.0s" $(seq 1 $leftIndent)
  fi
  echo "$2"
}

verboseEcho() {
  if [ "$VERBOSE" = true ]; then
    echo "$1"
  fi
}

exitWithError() {
  >&2 echo -e "ERROR: $*"
  exit 1
}

# Self update {{{1

runSelfUpdate() {
  # Tnx: https://stackoverflow.com/q/8595751/3968618
  echo "Performing self-update..."

  echo "Downloading latest version..."
  curl $SELF_UPDATE_URL -o "$0.tmp"
  exitCode=$?
  if [ $exitCode -ne 0 ]; then
    exitWithError "Update failed: Error downloading."
  fi

  # Copy over modes from old version
  filePermissions=$(stat -c '%a' "$0" 2> /dev/null)
  exitCode=$?
  if [ $exitCode -ne 0 ]; then
    filePermissions=$(stat -f '%A' "$0")
  fi
  if ! chmod "$filePermissions" "$0.tmp" ; then
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

# assert $1 equals $2
#
# $1 - expected
# $2 - actual
# $3 - message (optional)
assertEquals() {
  local exp="$1"; shift
  local act="$1"; shift
  if [ "$act" != "$exp" ]; then
    failFromStackDepth 2 "$(formatAValueBValue "expected:" "$exp" "got:" "$act" "$@")"
  fi
}

# assert $1 does not equal $2
#
# $1 - expected
# $2 - actual
# $3 - message (optional)
assertNotEquals() {
  local exp="$1"; shift
  local act="$1"; shift
  if [ "$act" = "$exp" ]; then
    failFromStackDepth 2 "$(formatAValueBValue "expected:" "$exp" "to not equal:" "$act" "$@")"
  fi
}

# assert $1 matches $2 (uses =~ bash builtin matching)
#
# $1 - expected regex
# $2 - actual
# $3 - message (optional)
assertMatches() {
  local regex="$1"; shift
  local act="$1"; shift
  if [[ ! "$act" =~ $regex ]]; then
    failFromStackDepth 2 "$(formatAValueBValue "expected regex:" "$regex" "to match:" "$act" "$@")"
  fi
}

# assert $1 does NOT match $2 (uses =~ bash builtin matching)
#
# $1 - expected regex
# $2 - actual
# $3 - message (optional)
assertNotMatches() {
  local regex="$1"; shift
  local act="$1"; shift
  if [[ "$act" =~ $regex ]]; then
    failFromStackDepth 2 "$(formatAValueBValue "expected regex:" "$regex" "to NOT match:" "$act" "$@")"
  fi
}

# assert file exists and is a file
#
# $1 - filepath
assertFileExists() {
  if [ ! -e "$1" ]; then failFromStackDepth 2 "Expected file '$1' to exist."; fi
  if [ ! -f "$1" ]; then failFromStackDepth 2 "Expected '$1' to be a file."; fi
}

# assert file does not exist
#
# $1 - filepath
assertFileNotExists() {
  if [ -e $1 ]; then failFromStackDepth 2 "Expected file '$1' to NOT exist."; fi
}

# assert file exists and is a directory
#
# $1 - path
assertDirExists() {
  if [ ! -e $1 ]; then failFromStackDepth 2 "Expected dir '$1' to exist."; fi
  if [ ! -d $1 ]; then failFromStackDepth 2 "Expected '$1' to be a directory."; fi
}

# assert dir does not exist
#
# $1 - path
assertDirNotExists() {
  if [ -d $1 ]; then failFromStackDepth 2 "Expected dir '$1' to NOT exist."; fi
}

# Make sure a file contains a specific string or matches a regex
# 
# $1 - matcher (uses grep with no flags)
# $2 - file to look into
# $3 - message (optional)
assertFileContains() {
  local msg=""
  if [ "$#" -gt 2 ]; then msg="$3\n"; fi
  if [ ! -e "$2" ]; then failFromStackDepth 2 "${msg}File '$2' doesn't exist"; fi
  grep -q "$1" "$2" || failFromStackDepth 2 "${msg}Expected file '$2' contents to match grep: '$1'"
}

# Make sure a file does NOT contain a specific string or doesn't matche a regex
# 
# $1 - matcher (uses grep with no flags)
# $2 - file to look into
# $3 - Optional custom message
assertFileNotContains() {
  local msg=""
  if [ "$#" -gt 2 ]; then msg="$3\n"; fi
  if [ ! -e "$2" ]; then failFromStackDepth 2 "${msg}File '$2' doesn't exist"; fi
  grep -q "$1" "$2" && failFromStackDepth 2 "${msg}Expected file '$2' contents to NOT match grep: '$1'\n    found:$(grep "$1" "$2")"
}

# assert the last exist code was the provided one
# 
# $1 - expected exit code
# $2 - message (optional)
assertExitCodeEquals() {
  exitCode=$?
  exp="$1"; shift
  if [ $exitCode -ne $exp ]; then
    failFromStackDepth 2 "$(formatAValueBValue "expected exit code:" "$exp" "got:" "$exitCode" "$2")"
  fi
}

# assert the last exist code was NOT the one provided
# 
# $1 - expected exit code
# $2 - message (optional)
assertExitCodeNotEquals() {
  exitCode=$?
  exp="$1"; shift
  # unlike the positive case, which fails descriptivly even when no number is
  # provided, here we also check if it's even a number by using -eq (which only
  # works with numbers) comparing it to itself
  if ! [ "$exp" -eq "$exp" ] 2>/dev/null; then 
    failFromStackDepth 2 "Provided expected exit code is invalid: '$exp'"
  fi
  if [ $exitCode = "$exp" ]; then
    failFromStackDepth 2 "$(formatAValueBValue "expected exit code to not be:" "$exp" "but got:" "$exitCode" "$@")"
  fi
}

# explicityl fails this test. 
# 
# $1 - message
fail() {
  failFromStackDepth 2 "$1"
}

# Main {{{1
# Main entry point (excluded from tests)
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main "$@"
fi
# vim:fdm=marker
