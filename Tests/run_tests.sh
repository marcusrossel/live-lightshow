#!/bin/bash

# This script is used to run all test-files in the directory of this script. A test-file is any file
# whose name starts with "test_".

# TODO: Add test suites for `push_program.sh` and library-functions.


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)


#-Main------------------------------------------#


# Gets every file starting with "test_" in the script's directory.
for test_script in "$dot/test_"*; do
   # Runs every script after newlining.
   echo
   "$test_script"
done
