#!/usr/bin/env bash

help() {
  cat << EOF
An example script.
EOF
exit
}

main() {
  # parse script arguments here.
  while getopts "hv" opt; do
    case $opt in
      h)
        help
        ;;
      v)
        export VERBOSE=true
        ;;
      *)
        help
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  echo "main method"

  sourceThing
  setupHome
  downloadThing
}

sourceThing() {
  echo "source .bashrc" > $HOME/someFile.txt
}

setupHome() {
  mkdir -p $HOME/bin
}

isMultilineFile() {
  [[ "$(cat $HOME/someFile.txt | wc -l)" -gt 1 ]] && echo "true" || echo "false"
}

downloadThing() {
  curl https://raw.githubusercontent.com/meonlol/t-bash/master/runTests.sh -o $HOME/bin/runTests.sh
}

# Bash runs code as it interprets it, except for functions. We can write code
# like normal by packing everthing in a function and calling main at the end.
if [[ "$0" == "$BASH_SOURCE" ]]; then
  # If the main file is the current file, we calling the script directly and
  # can call main. Otherwise, we are calling it from a test.
  main $@
fi

