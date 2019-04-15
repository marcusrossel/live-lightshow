#!/bin/bash


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports testing and CLI utilities.
. "$_dot/../Libraries/test_utilities.sh"
. "$_dot/../Libraries/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


readonly test_command="$dot/../Scripts/threshold_configuration.sh"
readonly test_ino_file="$dot/test_TC_ino_file.ino"


#-Setup-----------------------------------------#


echo "Testing \``basename "$test_command"`\` in \`${BASH_SOURCE##*/}\`:"
touch "$test_ino_file"


#-Cleanup---------------------------------------#


trap cleanup EXIT
function cleanup {
   rm "$test_ino_file"
}


#-Tests-Begin-----------------------------------#


# Test: Usage

silently- "$test_command" 1 2
report_if_last_status_was 1


# Test: Invalid file as argument

silently- "$test_command" invalid_file_path
report_if_last_status_was 2

# The test command itself is used as an instance of a file not ending in ".ino".
silently- "$test_command" "$test_command"
report_if_last_status_was 2


# Test: Empty `.ino`-file

>"$test_ino_file"

output=`silently- --stderr "$test_command" "$test_ino_file"`
report_if_output_matches "$output" ''


# Test: Potential declaration headers

cat << END >"$test_ino_file"
// #threshold "A
// #threshold B"
// #threshold "Actual"
const int a = 0;
// #threshold ":A"
// #threshold A
// #threshold "A" ...
// #threshold " "A" "
END

errors=`silently- --stdout "$test_command" "$test_ino_file" 2>&1`
report_if_output_matches --numeric "`wc -l <<< "$errors"`" 6


# Test: Duplicate microphone identifiers

cat << END >"$test_ino_file"
// #threshold "A"
// #threshold "B"
// #threshold "A"
END

silently- "$test_command" "$test_ino_file"
report_if_last_status_was 3


# Test: Malformed declaration body

cat << END >"$test_ino_file"
// #threshold "A"
const int a = 1;

// #threshold "B"
int b = 2;
END

silently- "$test_command" "$test_ino_file"
report_if_last_status_was 4


# Test: Perfect `.ino`-file

cat << END >"$test_ino_file"
// #threshold "A"
const int a = 1;

// #threshold "B C"
const int bc = 2;
END

output=`silently- --stderr "$test_command" "$test_ino_file"`
report_if_output_matches "$output" $'A: 1\nB C: 2'


# Test: `.ino`-file without declarations

cat << END >"$test_ino_file"
#include <stdio.h>
int main() {
   printf("hello world");
}
END

output=`silently- --stderr "$test_command" "$test_ino_file"`
report_if_output_matches "$output" ''


# Test: Messy `.ino`-file

cat << END >"$test_ino_file"
// #threshold "#threshold #1"
const int a = 1;

// #threshold "valid threshold"
const int _3complicated5Me = 123456789;

// #threshold "ignored threshold because of the " "
const int c = 0;

// #threshold "ignored threshold bacause of the :"
const int b = 0;

for (int i = 0; i < 10; i++) {
   printf("Index: %d", i);
}

// #threshold "b"
const int _2complicated4Me = 123;

// #threshol "ignored threshold declaration"
int thisDoesntMatter = -1;

// #threshold "ignored again
char againDoesntMatter = 'a';
END

output=`silently- --stderr "$test_command" "$test_ino_file"`
report_if_output_matches "$output" $'#threshold #1: 1\nvalid threshold: 123456789\nb: 123'


#-Tests-End-------------------------------------#


exit 0
