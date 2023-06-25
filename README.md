![Build Status](https://github.com/leonschreuder/t-bash/actions/workflows/run_tests.yml/badge.svg)



# t-bash
A tiny self-updating testing framework for bash.

**NOTICE**

This project is not updated regularly because it is basically feature-complete.
I use it quite a lot still, so feel free to use it too.

## Usage
A terminal says more than a 1000 words.

```
$ ls -l
total 24
-rwxr-xr-x  1 meonlol  staff  10212 21 Apr 11:38 runTests.sh
-rw-r--r--  1 meonlol  staff   1059 21 Apr 11:21 myscript.sh
-rw-r--r--  1 meonlol  staff   1749 21 Apr 11:21 test_myscript.sh

$ ./runTests.sh
.....
FAIL: ./test_myscript.sh(27) > test__fails_when_not_equal
    expected: 'a', got: 'b'
1 failing tests in 1 files
TEST SUITE FAILED
```

## Background

I found that bash scripts become really complex really fast, and can be quite
tricky to get stable enough for lots of people to use. **t-bash** is here to help
and provides a robust but minimal testing framework you can put next to your
scripts for anyone to use.

## What it is

Basicly, it is a simple test-runner script you can put in your repo next to the
scripts you are testing. When you call it, it searches all `test_*` files for
functions with the `test_` or `testLarge_` prefix, and runs them.

Basic asserts are included, extended matchers are in the `extended_matchers.sh`
file if you even need them. You can also put the script in your PATH and call it
from anywhere if you like.

## Built-in matchers:

This is usually all you need:
```
assertEquals "equality" "equality"        # all your basic comparison needs.
assertMatches "^ma.*ng$" "matching"       # I want to practice my regex
assertNotEquals "same" "equality"         # Anything but this.
assertNotMatches "^ma.*ng$" "equality"    # I know regex so well I'm sure this works. 
fail "msg"                                # I write my own damd checks, thank you!
```

Custom checks are easily built using if-statements and the fail function:
```
[[ ! -f ./my/marker.txt ]] && fail "Where did my file go?"
```
..but there are some more pre-built asserts in `extended_matchers.sh`.

## More info

See the `-h` help for more detaild info, and have a look under `examples/` for
some basic and extended exmples.


## Disclaimer
Bash is still bash, and if your code uses subshelling, environment variables,
scoping or loading other files or variables, you can make bugs that are realy
hard to find. Try to keep it simple.

Also note that coloring, tabs/spaces or other invisible characters might make
assertEquals fail without showing exactly what is going wrong. You can use the
-e flag to use extended diffing, but it might still be hard to tell.
