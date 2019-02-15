
export TMP_DIR="$(pwd)/tmp_test"

setup() {
  mkdir -p $TMP_DIR
  source extended_matchers.sh
}

teardown() {
  rm -rf $TMP_DIR
}

test__asserting_file_exist() {
  assertMatches "^FAIL" "$(assertFileExists "$TMP_DIR/someFile.txt")"
  assertEquals "" "$(assertFileNotExists "$TMP_DIR/someFile.txt")"

  touch $TMP_DIR/someFile.txt
  assertEquals "" "$(assertFileExists "$TMP_DIR/someFile.txt")"
  assertMatches "^FAIL" "$(assertFileNotExists "$TMP_DIR/someFile.txt")"
}

test__asserting_dir_exist() {
  assertMatches "^FAIL" "$(assertDirExists "$TMP_DIR/some-dir")"
  assertEquals "" "$(assertDirNotExists "$TMP_DIR/some-dir")"

  mkdir $TMP_DIR/some-dir
  assertEquals "" "$(assertDirExists "$TMP_DIR/some-dir")"
  assertMatches "^FAIL" "$(assertDirNotExists "$TMP_DIR/some-dir")"
}

test__asserting_file_contents() {
  echo -e "line1\nline2\nline3\n" > $TMP_DIR/someFile.txt

  assertEquals "" "$(assertFileContains "line2" "$TMP_DIR/someFile.txt")"
  assertMatches "^FAIL" "$(assertFileContains "line4" "$TMP_DIR/someFile.txt")"

  assertEquals "" "$(assertFileNotContains "line5" "$TMP_DIR/someFile.txt")"
  assertMatches "^FAIL" "$(assertFileNotContains "line2" "$TMP_DIR/someFile.txt")"
}

