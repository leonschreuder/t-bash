#!/bin/bash

if [[ "$TRAVIS_EVENT_TYPE" != "pull_request" ]]; then
  echo "only checking version change in Pull Requests. Skipping... "
  exit
fi

if ! git diff $TRAVIS_COMMIT_RANGE | grep -q "SCRIPT_VERSION"; then
  echo "ERROR: update to script version is required in pull request build."
  exit 1
else
  echo "SUCCESS: Script version is modified."
fi
