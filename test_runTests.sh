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
}

teardown() {
  VERBOSE=$_REAL_VERBOSE
  TIMED=$_REAL_TIMED
  MATCH=$_REAL_MATCH
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

test__when_matching_should_call_matching_test() (
  mock_function() { echo "mock_function called"; }

  MATCH="*ock_func*"
  result="$(callTest "mock_function")"

  assertEquals "mock_function called" "$result"
)

test__when_matching_should_not_call_non_matching_test() (
  mock_function() { echo "mock_function called"; }

  MATCH="*testDouble*"
  result="$(callTest "mock_function")"

  assertEquals "" "$result"
)

test__should_print_time_when_required() (
  overwriteEnv
  export TIMED="true" 

  result="$(callTest "mock_function" 2>&1 )"

  assertEquals "$(echo -e "mock_function\nmock_function called\nreal 0.00\nuser 0.00\nsys 0.00" )" "$result"
)



# HELPERS
#--------------------------------------------------------------------------------

mock_function() { echo "mock_function called"; }

overwriteEnv() {
  setup() { echo -n ""; }; teardown() { echo -n ""; }
}