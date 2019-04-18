#!/bin/bash


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting and testing utilities.
. "$dot/scripting.sh"
. "$dot/testing.sh"


#-Constants-------------------------------------#


readonly test_command="$dot/../Scripts/configure_thresholds.sh"
readonly test_program_folder="$dot/test_CT_program_folder"
readonly test_ino_file="$test_program_folder/test_ino_file.ino"


#-Setup-----------------------------------------#


echo "Testing \``basename "$test_command"`\` in \`${BASH_SOURCE##*/}\`:"
mkdir "$test_program_folder"
touch "$test_ino_file"


#-Cleanup---------------------------------------#


trap cleanup EXIT
function cleanup {
   rm -r "$test_program_folder"
}


#-Tests-Begin-----------------------------------#


# Test: Usage


silently- "$test_command" 1 2
report_if_last_status_was 1


#-Tests-End-------------------------------------#


exit 0
