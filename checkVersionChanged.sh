#!/bin/bash


echo "TRAVIS_COMMIT_RANGE:$TRAVIS_COMMIT_RANGE"

COMMIT_RANGE="$(echo ${TRAVIS_COMMIT_RANGE} | cut -d '.' -f 1,4 --output-delimiter '..')"
CHANGED_FILES="$(git diff --name-only ${COMMIT_RANGE} --)"

echo "CHANGED_FILES:$CHANGED_FILES"
