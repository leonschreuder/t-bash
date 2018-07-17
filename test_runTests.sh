# Should a testing framework be tested with itself? Probably not, but it does
# give you a good example of how to use it.
_REAL_VERBOSE=$VERBOSE
_REAL_TIMED=$TIMED
_REAL_MATCH=$MATCH

setup() {
  unset VERBOSE
  unset TIMED
  unset MATCH
    # You should normally load the script under test
    #source ./runTests.sh
  mkdir -p ./tmp
}

teardown() {
  VERBOSE=$_REAL_VERBOSE
  TIMED=$_REAL_TIMED
  MATCH=$_REAL_MATCH
  rm -rf ./tmp
}

test_logger_should_only_log_when_verbose() {
  result=$(logv "message")
  assertEquals "" "$result"

  VERBOSE=true
  result=$(logv "message")
  assertEquals "message" "$result"
}

test_assert_equals_should_not_print_anything_when_equal() {
  result=$(assertEquals "some string" "some string")
  assertEquals "" "$result"
}

test_assert_equals_should_print_fail_when_unequals() {
  assertLineNo=$(($LINENO+1))
  result=$(assertEquals "some strin" "some string")

  # This gets really hard to read.
  expected="FAIL: ./test_runTests.sh($assertLineNo) > test_assert_equals_should_print_fail_when_unequals
    expected: 'some strin', got: 'some string'"
  assertEquals "$expected" "$result"
}

test_fail_should_print_correctly() {
  assertLineNo=$(($LINENO+1))
  result=$(fail "Message")

  # This gets really hard to read.
  expected="FAIL: ./test_runTests.sh($assertLineNo) > test_fail_should_print_correctly
    Message"
  assertEquals "$expected" "$result"
}

test__call_if_exists() {
  result="$(callIfExists "mock_function")"
  assertEquals "mock_function called" "$result"
}

test__should_call_provided_test() {
  result="$(callTest "mock_function")"
  assertEquals "mock_function called" "$result"
}

test__should_call_setup_and_teardown() (
  setup() { echo "setup called"; }
  teardown() { echo "teardown called"; }

  result="$(callTest "mock_function")"

  assertEquals "$( echo -e "setup called\nmock_function called\nteardown called")" "$result"
)

test__should_call_suiteSetup_and_stuiteTeardown() (
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
fileSetup() { :; }
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
fileTeardown() { :; }
EOF

  (cd tmp; ./runTests.sh -v > result.log)

  assertEquals "$(cat << EOF
running ./test_test.sh
  fileSetup
  test_t1
  test_t2
  test_t3
  fileTeardown
suite successfull
EOF
  )" "$(cat tmp/result.log)"
)

test__suiteSetup_should_fail_all_tests() (
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
fileSetup() { return 3; }
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
fileTeardown() { :; }
EOF

  (cd tmp; ./runTests.sh -v > result.log)

  assertEquals "$(cat << EOF
running ./test_test.sh
  fileSetup
FAIL: fileSetup failed.
3 failing tests in 1 files
TEST SUITE FAILED
EOF
  )" "$(cat tmp/result.log)"
)

test__when_matching_should_call_matching_test() (
  test_mock_function() { echo "mock_function called"; }
  VERBOSE=true

  MATCH="*ock_func*"
  result="$(callFuncIfTest "test_mock_function")"

  assertEquals "$(echo -e "  test_mock_function\nmock_function called")" "$result"
)

test__when_has_match_should_not_get_non_matching_test() (
  test_mock_function() { echo "mock_function called"; }

  MATCH="*testDouble*"

  assertEquals "" "$(getTestFuncs)"
)

test__should_print_time_when_required() (
  overwriteEnv
  export TIMED="true" 

  result="$(callTest "mock_function" 2>&1 )"

  assertEquals "$(echo -e "mock_function\nmock_function called\nreal 0.00\nuser 0.00\nsys 0.00" )" "$result"
)

testLarge__should_run_basic_test() {
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
test_t1() {
  :
}
EOF
  (cd tmp; ./runTests.sh > result.log)
  assertEquals "$(cat << EOF

[1A.[1Bsuite successfull
EOF
  )" "$(cat tmp/result.log)"
}

testLarge__should_run_basic_test_verbose() {
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
test_t1() { :; }
EOF
  (cd tmp; ./runTests.sh -v > result.log)
  assertEquals "$(cat << EOF
running ./test_test.sh
  test_t1
suite successfull
EOF
  )" "$(cat tmp/result.log)"
}

testLarge__should_run_multiple_tests() {
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
EOF

  (cd tmp; ./runTests.sh > result.log)

  assertEquals "$(cat << EOF

[1A.[1B[1A..[1B[1A...[1Bsuite successfull
EOF
  )" "$(cat tmp/result.log)"
}

testLarge__should_run_multiple_tests_verbose() {
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
EOF

  (cd tmp; ./runTests.sh -v > result.log)

  assertEquals "$(cat << EOF
running ./test_test.sh
  test_t1
  test_t2
  test_t3
suite successfull
EOF
  )" "$(cat tmp/result.log)"
}


testLarge__should_fail_suite_on_failing_test() {
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
test_t1() { fail "error-message"; }
EOF
  (cd tmp; ./runTests.sh -v > result.log)
  assertEquals "$(cat << EOF
running ./test_test.sh
  test_t1
FAIL: ./test_test.sh(1) > test_t1
    error-message
1 failing tests in 1 files
TEST SUITE FAILED
EOF
  )" "$(cat tmp/result.log)"
}


testLarge__should_fail_suite_for_multiple_failing_tests() {
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
test_t1() { fail "error-message"; }
test_t2() { fail "error-message"; }
test_t3() { fail "error-message"; }
EOF
  (cd tmp; ./runTests.sh -v > result.log)
  assertEquals "$(cat << EOF
running ./test_test.sh
  test_t1
FAIL: ./test_test.sh(1) > test_t1
    error-message
  test_t2
FAIL: ./test_test.sh(2) > test_t2
    error-message
  test_t3
FAIL: ./test_test.sh(3) > test_t3
    error-message
3 failing tests in 1 files
TEST SUITE FAILED
EOF
  )" "$(cat tmp/result.log)"
}

testLarge__should_respect_matcher() {
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
EOF

  (cd tmp; ./runTests.sh -vm test_t2 > result.log)

  assertEquals "$(cat << EOF
running ./test_test.sh
  test_t2
suite successfull
EOF
  )" "$(cat tmp/result.log)"
}

testLarge__should_respect_matcher_on_verbose_output() {
  cp ./runTests.sh ./tmp/
cat << EOF >> ./tmp/test_test.sh
test_t1() { :; }
test_t2() { :; }
test_t3() { :; }
EOF

  (cd tmp; ./runTests.sh -m test_t2 > result.log)

  assertEquals "$(cat << EOF

[1A.[1Bsuite successfull
EOF
  )" "$(cat tmp/result.log)"
}


# HELPERS
#--------------------------------------------------------------------------------

mock_function() { echo "mock_function called"; }

overwriteEnv() {
  setup() { echo -n ""; }; teardown() { echo -n ""; }
}
