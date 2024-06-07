# Should a testing framework be tested with itself? Probably not, but it does
# give you a good example of how to use it.
_REAL_VERBOSE=$VERBOSE
_REAL_TIMED=$TIMED
_REAL_MATCH=$MATCH
_REAL_RUN_LARGE_TESTS=$RUN_LARGE_TESTS
_REAL_EXTENDED_DIFF=$EXTENDED_DIFF
_REAL_COLOR_OUTPUT=$COLOR_OUTPUT

TMP_TEST="$(pwd)/tmp_test"

#TODO: cleanup
#TODO: Code performance?
#TODO: Test scoping in test functions.

setup() {
  # You should normally load the script under test
  #source ./runTests.sh
  clearEnvVars
  mkdir -p $TMP_TEST
}

teardown() {
  resetEnvVars
  rm -rf $TMP_TEST
}

clearEnvVars() {
  unset VERBOSE
  unset TIMED
  unset MATCH
  unset RUN_LARGE_TESTS
  unset EXTENDED_DIFF
  unset COLOR_OUTPUT
  unset HIGHLIGHT_WHITESPACE
}

resetEnvVars() {
  VERBOSE=$_REAL_VERBOSE
  TIMED=$_REAL_TIMED
  MATCH=$_REAL_MATCH
  RUN_LARGE_TESTS=$_REAL_RUN_LARGE_TESTS
  EXTENDED_DIFF=$_REAL_EXTENDED_DIFF
  COLOR_OUTPUT=$_REAL_COLOR_OUTPUT
}

# Succesfull tests {{{1

testLarge__should_run_basic_test() {
  createMockTestFile "test_t1() { :; }"

  result=$(runMockTests)
  resetEnvVars

  assertMatches "suite successfull" "$result"
  assertEquals "
[1A.[1Bsuite successfull" "$result"
}



testLarge__should_run_basic_test_verbose() {
  createMockTestFile "test_t1() { :; }"

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "running ./test_test1.sh" "$result"
  assertMatches "test_t1" "$result"
  assertMatches "suite successfull" "$result"
  assertEquals "running ./test_test1.sh
  test_t1
suite successfull" "$result"
}

testLarge__should_run_multiple_tests() {
  createMockTestFile "
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
"

  result=$(runMockTests)
  resetEnvVars

  assertMatches "\.\.\." "$result"
  assertMatches "suite successfull" "$result"
  assertEquals "
[1A.[1B[1A..[1B[1A...[1Bsuite successfull" "$result"
}

testLarge__should_run_multiple_tests_verbose() {
  createMockTestFile "
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
"

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "test_t1" "$result"
  assertMatches "test_t2" "$result"
  assertMatches "test_t3" "$result"
  assertMatches "suite successfull" "$result"
  assertEquals "running ./test_test1.sh
  test_t1
  test_t2
  test_t3
suite successfull" "$result"
}

testLarge__should_run_multiple_files_verbose() {
  createMockTestFile "
test_t1() { :; }
"
  createMockTestFile "
test_t2() { :; }
"

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "running ./test_test1.sh" "$result"
  assertMatches "running ./test_test2.sh" "$result"
  assertMatches "test_t1" "$result"
  assertMatches "test_t2" "$result"
  assertMatches "suite successfull" "$result"
  assertEquals "running ./test_test1.sh
  test_t1
running ./test_test2.sh
  test_t2
suite successfull" "$result"
}
# Failing tests {{{1
testLarge__should_fail_suite_on_failing_test() {
  createMockTestFile 'test_t1() { fail "error-message"; }'

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "FAIL: \./test_test1.sh\(1\) > test_t1" "$result"
  assertMatches "TEST SUITE FAILED" "$result"
  assertMatches "error-message" "$result"
  assertMatches "1 failing tests in 1 files" "$result"
  assertEquals "running ./test_test1.sh
  test_t1
FAIL: ./test_test1.sh(1) > test_t1
    error-message
1 failing tests in 1 files
TEST SUITE FAILED" "$result"
}


testLarge__should_fail_suite_for_multiple_failing_tests() {
createMockTestFile '
test_t1() { fail "error-message"; }
test_t2() { fail "error-message"; }
test_t3() { fail "error-message"; }'

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "FAIL: \./test_test1.sh\([0-9]\) > test_t1" "$result"
  assertMatches "FAIL: \./test_test1.sh\([0-9]\) > test_t2" "$result"
  assertMatches "FAIL: \./test_test1.sh\([0-9]\) > test_t3" "$result"
  assertMatches "3" "$(echo "$result" | grep "error-message" | wc -l )"
  assertMatches "TEST SUITE FAILED" "$result"
  assertMatches "3 failing tests in 1 files" "$result"
  assertEquals "$(cat << EOF
running ./test_test1.sh
  test_t1
FAIL: ./test_test1.sh(2) > test_t1
    error-message
  test_t2
FAIL: ./test_test1.sh(3) > test_t2
    error-message
  test_t3
FAIL: ./test_test1.sh(4) > test_t3
    error-message
3 failing tests in 1 files
TEST SUITE FAILED
EOF
  )" "$result"
}

testLarge__should_warn_if_no_test_found() {
  createMockTestFile ''

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "no tests found" "$result"
  assertMatches "suite successfull" "$result"
  assertEquals "running ./test_test1.sh
no tests found
suite successfull" "$result"
}

testLarge__should_fail_test_when_exited_with_error_but_no_output() {
  createMockTestFile '
test_t1() { exit 1; }
test_t2() { fail "error-message"; }
  '

  result=$(runMockTests)
  resetEnvVars

  assertMatches "TEST SUITE FAILED" "$result"
  assertMatches "2 failing tests in 1 files" "$result"
  assertMatches "./test_test1.sh\(\?\) > test_t1" "$result"
  assertEquals "
[1A.[1BFAIL: ./test_test1.sh(?) > test_t1
    Test failed without printing anything.
[3A..[3BFAIL: ./test_test1.sh(3) > test_t2
    error-message
2 failing tests in 1 files
TEST SUITE FAILED" "$result"
}

testLarge__should_fail_test_when_exited_with_error_but_no_output_verbose() {
  createMockTestFile '
test_t1() { exit 1; }
test_t2() { fail "error-message"; }
  '

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "TEST SUITE FAILED" "$result"
  assertMatches "2 failing tests in 1 files" "$result"
  assertMatches "./test_test1.sh\(\?\) > test_t1" "$result"
  assertEquals "running ./test_test1.sh
  test_t1
FAIL: ./test_test1.sh(?) > test_t1
    Test failed without printing anything.
  test_t2
FAIL: ./test_test1.sh(3) > test_t2
    error-message
2 failing tests in 1 files
TEST SUITE FAILED" "$result"
}

# Test output {{{1

test__should_print_output() {
  createMockTestFile '
test_t1() { echo one; }
test_t2() { echo -e "two\nthree"; }
'

  result=$(runMockTests)
  resetEnvVars

  assertMatches "one" "$result"
  assertMatches "two" "$result"
  assertMatches "three" "$result"
  assertEquals "
[1A.[1Bone
[2A..[2Btwo
three
suite successfull" "$result"
}

test__should_print_output_verbose() {
  createMockTestFile '
test_t1() { echo one; }
test_t2() { echo -e "two\nthree"; }
'

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "one" "$result"
  assertMatches "two" "$result"
  assertMatches "three" "$result"
  assertEquals "running ./test_test1.sh
  test_t1
one
  test_t2
two
three
suite successfull" "$result"
}

# Matching tests {{{1

test__has_match_should_only_get_matching_test() (
  compgen() { echo -e "test_mock_some_function\ntestLarge_mock_other_function" ;}
  unset RUN_LARGE_TESTS

  assertEquals "test_mock_some_function" "$(getTestFuncs)"
)

testLarge__should_respect_matcher() {
  createMockTestFile "
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
"

  result=$(runMockTests -m test_t2)
  resetEnvVars

  assertMatches "\." "$result"
  assertNotMatches "\.\.\." "$result"
  assertEquals "
[1A.[1Bsuite successfull" "$result"
}

testLarge__should_respect_matcher_on_verbose_output() {
createMockTestFile '
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }'

  result=$(runMockTests -vm test_t2)
  resetEnvVars

  assertMatches "test_t2" "$result"
  assertNotMatches "test_t1" "$result"
  assertNotMatches "test_t3" "$result"
  assertEquals "running ./test_test1.sh
  test_t2
suite successfull" "$result"
}

test__getTestFuncs_should_only_get_matching_test() (
  test_mock_some_function() { :; }
  test_mock_other_function() { :; }
  test_mock_matching_function() { :; }
  testLarge_mock_other_function() { :; }

  MATCH="mock_matching"

  assertEquals "test_mock_matching_function" "$(getTestFuncs)" #carefull, getTestFuncs also returns the tests in this file
)

test__when_has_match_should_only_get_matching_test() (
  test_mock_some_function() { :; }
  test_mock_other_function() { :; }
  test_mock_matching_function() { :; }
  testLarge_mock_other_function() { :; }
  some_other_mock_matching_function() { :; }

  MATCH="mock_matching"

  assertEquals "test_mock_matching_function" "$(getTestFuncs)" #carefull, getTestFuncs also returns the tests in this file
)

test__matcher_should_also_match_large_tests() (
  test_mock_some_function() { :; }
  testLarge_mock_other_function() { :; }
  testLarge_mock_matching_function() { :; }

  MATCH="mock_matching"

  assertEquals "testLarge_mock_matching_function" "$(getTestFuncs)" #carefull, getTestFuncs also returns the tests in this file
)

# Setup & teardown {{{1

test__should_call_setup_and_teardown_with_exceptions() (
createMockTestFile '
setup() { echo "setup called"; }
teardown() { echo "teardown called"; }
test_t1() { echo "method"; }
test_t2() { fail "method failed"; }
test_t3() { exit 1; }
test_t4() { assertMatches "a" "b" ; }'

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "setup called" "$result"
  assertMatches "teardown called" "$result"
  assertMatches "4" "$(echo "$result" | grep "setup called" | wc -l)"
  assertMatches "4" "$(echo "$result" | grep "teardown called" | wc -l)"
  assertEquals "$(cat << EOF
running ./test_test1.sh
  test_t1
setup called
method
teardown called
  test_t2
setup called
FAIL: ./test_test1.sh(5) > test_t2
    method failed
teardown called
  test_t3
setup called
teardown called
  test_t4
setup called
FAIL: ./test_test1.sh(7) > test_t4
    expected regex: 'a', to match: 'b'
teardown called
3 failing tests in 1 files
TEST SUITE FAILED
EOF
  )" "$result"
)

test__should_call_fileSetup_and_fileTeardown() (
createMockTestFile '
fileSetup() { :; }
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
fileTeardown() { :; }'


  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "fileSetup" "$result"
  assertMatches "fileTeardown" "$result"
  assertEquals "$(cat << EOF
running ./test_test1.sh
  fileSetup
  test_t1
  test_t2
  test_t3
  fileTeardown
suite successfull
EOF
  )" "$result"
)

test__fileSetup_should_fail_all_tests() (
createMockTestFile '
fileSetup() { return 3; }
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
fileTeardown() { :; }'

  result=$(runMockTests -v)
  resetEnvVars

  assertMatches "3 failing tests in 1 files" "$result"
  assertEquals "running ./test_test1.sh
  fileSetup
FAIL: fileSetup failed.
3 failing tests in 1 files
TEST SUITE FAILED" "$result"
)

test__should_call_setup_and_teardown() (
  setup() { echo "setup called"; }
  teardown() { echo "teardown called"; }

  result="$(runTest "mock_function")"

  assertEquals "$( echo -e "setup called\nmock_function called\nteardown called")" "$result"
)

# Time {{{1

testLarge__should_print_time() {
  createMockTestFile "test_t1() { :; }"
  export LC_ALL=C # number formatting always with dot

  result=$(runMockTests -t)
  resetEnvVars

  # notice it is the same as verbose
  assertMatches "suite successfull" "$result"
  assertEquals "running ./test_test1.sh
  test_t1
real 0.00
user 0.00
sys 0.00

suite successfull" "$result"
}

testLarge__should_print_time_verbose() {
  createMockTestFile "test_t1() { :; }"
  export LC_ALL=C # number formatting always with dot

  result=$(runMockTests -vt)
  resetEnvVars

  # notice above the output is always verbose
  assertMatches "suite successfull" "$result"
  assertEquals "running ./test_test1.sh
  test_t1
real 0.00
user 0.00
sys 0.00

suite successfull" "$result"
}

# format expected got {{{1

test__should_format_simple_exception() {
  result="$(formatAValueBValue "expected:" "a" "got:" "b")"
  assertEquals "expected: 'a', got: 'b'" "$result"
}

test__should_format_simple_exception_color() {
  export COLOR_OUTPUT="true"
  colorResult="$(formatAValueBValue "expected:" "a" "got:" "b")"

  export COLOR_OUTPUT="false"
  assertEquals "expected: '${COLOR_GREEN}a$COLOR_NONE', got: '${COLOR_RED}b$COLOR_NONE'" "$colorResult"
}

test__should_format_longer_exception_on_two_lines() {
  expected="compare two rather long strings a"
  got="compare two rather long strings b"

  result="$(formatAValueBValue "expected:" "$expected" "got:" "$got")"

  assertEquals "$(echo -en "expected: '$expected'\n     got: '$got'")" "$result"
}

test__should_format_multiline_exception_on_seperate_lines() {
  expected="line 1
line 2"
  got="line a
line b"

  result="$(formatAValueBValue "expected:" "$expected" "got:" "$got")"

  assertEquals "$(echo -en "> expected:\n$expected\n> got:\n$got")" "$result"
}

test__should_highlight_whitespace() {
  inA="line
  spaceIndent
	tabIndent"
  inB="line
spaceIndent
tabIndent"
  export HIGHLIGHT_WHITESPACE=true

  result="$(formatAValueBValue "A:" "$inA" "B:" "$inB")"
  unset HIGHLIGHT_WHITESPACE

# set listchars=tab:▸\ ,eol:¬,trail:·,nbsp:·

  expectedA="line¬
··spaceIndent¬
▸ tabIndent¬"
  expectedB="line¬
spaceIndent¬
tabIndent¬"

  assertEquals "$(echo -en "> A:\n$expectedA\n> B:\n$expectedB")" "$result"
}


# Helper functions {{{1

test_logger_should_only_log_when_verbose() {
  result=$(verboseEcho "message")
  assertEquals "" "$result"

  VERBOSE=true
  result=$(verboseEcho "message")
  assertEquals "message" "$result"
}

test__call_if_exists() {
  result="$(callIfExists "mock_function")"
  assertEquals "mock_function called" "$result"
}

test__getWithOfWidestString() {
  assertEquals 5 "$(getWithOfWidestString "123" "12345")"
  assertEquals 6 "$(getWithOfWidestString "123456" "1234")"
  assertEquals 9 "$(getWithOfWidestString "expected:" "got:")"
}

test__rightAlign() {
  assertEquals " 234" "$(rightAlign 4 "234")"
  assertEquals "  234" "$(rightAlign 5 "234")"
  assertEquals "       abc" "$(rightAlign 10 "abc")"
  assertEquals "expected:" "$(rightAlign 9 "expected:")"
  assertEquals "     got:" "$(rightAlign 9 "got:")"
}


# Asserts {{{1

test__equals__should_not_print_anything_when_equal() {
  result=$(assertEquals "some string" "some string")
  assertEquals "" "$result"
}

test__equals__should_print_fail_when_unequals() {
  assertLineNo=$(( LINENO + 1))
  result=$(assertEquals "some strin" "some string")

  # This gets really hard to read.
  expected="FAIL: ./test_runTests.sh($assertLineNo) > test__equals__should_print_fail_when_unequals
    expected: 'some strin', got: 'some string'"
  assertEquals "$expected" "$result"
}

test__equals__should_print_log_if_provided() {
  assertLineNo=$(( LINENO + 1 ))
  result=$(assertEquals "some strin" "some string" "Error. Not found.")

  # This gets really hard to read.
  expected="FAIL: ./test_runTests.sh($assertLineNo) > test__equals__should_print_log_if_provided
    Error. Not found.
    expected: 'some strin', got: 'some string'"
  assertEquals "$expected" "$result"
}

test__matches__should_not_print_anything_when_matches() {
  result=$(assertMatches "match" "fluf match fluf")
  assertEquals "" "$result"

  result=$(assertMatches ".*match.*" "fluf match fluf")
  assertEquals "" "$result"
}

test__matches__should_print_fail() {
  result=$(assertMatches "somethingelse" "fluf match fluf")

  export COLOR_OUTPUT="true"
  assertMatches "FAIL:.*expected.regex: 'somethingelse'.* to match: 'fluf match fluf'" "$result"
}

test__matches__should_print_log_if_provided() {
  result=$(assertMatches "somethingelse" "fluf match fluf" "The one should match the other")

  export COLOR_OUTPUT="true"
  assertMatches "FAIL:.*expected.regex: 'somethingelse'.* to match: 'fluf match fluf'" "$result"
  assertMatches "The one should match the other" "$result"
}

test__fail__should_print_correctly() {
  assertLineNo=$(($LINENO+1))
  result=$(fail "Message")

  # This gets really hard to read.
  expected="FAIL: ./test_runTests.sh($assertLineNo) > test__fail__should_print_correctly
    Message"
  assertEquals "$expected" "$result"
}

test__asserting_file_exist() {
  assertMatches "^FAIL" "$(assertFileExists "$TMP_TEST/someFile.txt")"
  assertEquals "" "$(assertFileNotExists "$TMP_TEST/someFile.txt")"

  touch $TMP_TEST/someFile.txt
  assertEquals "" "$(assertFileExists "$TMP_TEST/someFile.txt")"
  assertMatches "^FAIL" "$(assertFileNotExists "$TMP_TEST/someFile.txt")"

  mkdir $TMP_TEST/some-dir
  assertMatches "^FAIL.*be a file" "$(assertFileExists "$TMP_TEST/some-dir")"
}

test__asserting_dir_exist() {
  assertMatches "^FAIL" "$(assertDirExists "$TMP_TEST/some-dir")"
  assertEquals "" "$(assertDirNotExists "$TMP_TEST/some-dir")"

  mkdir $TMP_TEST/some-dir
  assertEquals "" "$(assertDirExists "$TMP_TEST/some-dir")"
  assertMatches "^FAIL" "$(assertDirNotExists "$TMP_TEST/some-dir")"

  touch $TMP_TEST/someFile.txt
  assertMatches "^FAIL.*be a directory" "$(assertDirExists "$TMP_TEST/someFile.txt")"
}

test__asserting_file_contents() {
  echo -e "line1\nline2\nline3\n" > $TMP_TEST/someFile.txt

  assertEquals "" "$(assertFileContains "line2" "$TMP_TEST/someFile.txt")"
  assertMatches "^FAIL" "$(assertFileContains "line4" "$TMP_TEST/someFile.txt")"

  assertEquals "" "$(assertFileNotContains "line5" "$TMP_TEST/someFile.txt")"
  assertMatches "^FAIL" "$(assertFileNotContains "line2" "$TMP_TEST/someFile.txt")"
}


test__asserting_exit_code() {
  (exit 0)
  assertExitCodeEquals 0

  (exit 1)
  assertExitCodeEquals 1

  testF() { return 2; }
  testF
  assertExitCodeEquals 2

  testF
  assertExitCodeNotEquals 1
}


# HELPERS {{{1
#--------------------------------------------------------------------------------


createMockTestFile() {
  f="$TMP_TEST/test_test1.sh"
  [[ -f $f ]] && f="$TMP_TEST/test_test2.sh"
  echo "$@" >> $f
}

runMockTests() {
  clearEnvVars
  cd $TMP_TEST; ../runTests.sh $@
}


mock_function() { echo "mock_function called"; }

overwriteEnv() {
  setup() { echo -n ""; }; teardown() { echo -n ""; }
}
# vim:fdm=marker
