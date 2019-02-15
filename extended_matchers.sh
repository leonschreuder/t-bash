
assertFileExists() {
  [[ ! -f "$1" ]] && failFromStackDepth 2 "Expected file '$1' to exist."
}
assertFileNotExists() {
  [[ -f $1 ]] && failFromStackDepth 2 "Expected file '$1' to NOT exist."
}


assertDirExists() {
  [[ ! -d $1 ]] && failFromStackDepth 2 "Expected dir '$1' to exist."
}
assertDirNotExists() {
  [[ -d $1 ]] && failFromStackDepth 2 "Expected dir '$1' to NOT exist."
}


assertFileContains() {
  [[ ! -e "$2" ]] && failFromStackDepth 2 "File '$2' doesn't exist"
  grep -q "$1" "$2" || failFromStackDepth 2 "Expected file '$2' contents to match (grep):\n    '$matcher'"
}
assertFileNotContains() {
  [[ ! -e "$2" ]] && failFromStackDepth 2 "File '$2' doesn't exist"
  grep -q "$1" "$2" && failFromStackDepth 2 "Expected file '$2' contents to NOT match (grep):\n    '$matcher'"
}
