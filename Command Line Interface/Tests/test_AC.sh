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


readonly test_command="$dot/../Scripts/apply_configuration.sh"
readonly test_ino_file="$dot/test_AC_ino_file.ino"
readonly test_configuration="$dot/test_AC_configuration"


#-Setup-----------------------------------------#


echo "Testing \``basename "$test_command"`\` in \`${BASH_SOURCE##*/}\`:"
touch "$test_ino_file"
touch "$test_configuration"


#-Cleanup-----------------------------------------#


trap cleanup EXIT
function cleanup {
   rm "$test_ino_file"
   rm "$test_configuration"
}


#-Tests-Begin-----------------------------------#


# Test: Usage

silently- "$test_command"
report_if_last_status_was 1

silently- "$test_command" 1 2 3
report_if_last_status_was 1


# Test: Invalid file-paths and formats

silently- "$test_command" invalid_file "$test_ino_file"
report_if_last_status_was 2

silently- "$test_command" "$test_configuration" invalid_file
report_if_last_status_was 2

silently- "$test_command" "$test_configuration" "$test_configuration"
report_if_last_status_was 2


# Test: Malformed configuration entries

echo $'some valid: 123\nother valid: 001' >"$test_configuration"
silently- "$test_command" "$test_configuration" "$test_ino_file"
report_if_last_status_was 3

echo 'invalid: 123;' >"$test_configuration"
silently- "$test_command" "$test_configuration" "$test_ino_file"
report_if_last_status_was 3

echo 'invalid 456' >"$test_configuration"
silently- "$test_command" "$test_configuration" "$test_ino_file"
report_if_last_status_was 3

echo ':nvalid: 456' >"$test_configuration"
silently- "$test_command" "$test_configuration" "$test_ino_file"
report_if_last_status_was 3

echo 'invalid:9' >"$test_configuration"
silently- "$test_command" "$test_configuration" "$test_ino_file"
report_if_last_status_was 3


# Test: Configuration with duplicate microphone-identifier

echo $'duplicate: 1\nother: 2\nduplicate: 3' >"$test_configuration"
silently- "$test_command" "$test_configuration" "$test_ino_file"
report_if_last_status_was 4


# Test: Valid, equally sized configurations

echo $'first: 10\nsecond: 20\nthird: 30' >"$test_configuration"
cat << END >"$test_ino_file"
int something_before;

// #threshold "one"
const int threshold_declaration_0_value = 1;

int something_inbetween;

// #threshold "two"
const int threshold_declaration_1_value = 2;

// #threshold "three"
const int threshold_declaration_2_value = 3;

int something_after;
END

expected_output=`cat << END
int something_before;

// #threshold "first"
const int threshold_declaration_0_value = 10;

// #threshold "second"
const int threshold_declaration_1_value = 20;

// #threshold "third"
const int threshold_declaration_2_value = 30;

// #threshold-declarations-end

int something_inbetween;



int something_after;
END`

silently- "$test_command" "$test_configuration" "$test_ino_file"
report_if_output_matches "`cat "$test_ino_file"`" "$expected_output"


# Test: Valid, equally sized, dense configurations

echo $'first: 10\nsecond: 20\nthird: 30' >"$test_configuration"
cat << END >"$test_ino_file"
int something_before;
// #threshold "one"
const int threshold_declaration_0_value = 1;
int something_inbetween;
// #threshold "two"
const int threshold_declaration_1_value = 2;
// #threshold "three"
const int threshold_declaration_2_value = 3;
int something_after;
END

expected_output=`cat << END
int something_before;
// #threshold "first"
const int threshold_declaration_0_value = 10;

// #threshold "second"
const int threshold_declaration_1_value = 20;

// #threshold "third"
const int threshold_declaration_2_value = 30;

// #threshold-declarations-end
int something_inbetween;
int something_after;
END`

silently- "$test_command" "$test_configuration" "$test_ino_file"
report_if_output_matches "`cat "$test_ino_file"`" "$expected_output"


# Test: Valid, non-equally sized configurations

echo $'first: 10\nsecond: 20\nthird: 30' >"$test_configuration"
cat << END >"$test_ino_file"
int something_before;
// #threshold "just this one"
const int threshold_declaration_0_value = 987654321;
int something_after;
END

expected_output=`cat << END
int something_before;
// #threshold "first"
const int threshold_declaration_0_value = 10;

// #threshold "second"
const int threshold_declaration_1_value = 20;

// #threshold "third"
const int threshold_declaration_2_value = 30;

// #threshold-declarations-end
int something_after;
END`

silently- "$test_command" "$test_configuration" "$test_ino_file"
report_if_output_matches "`cat "$test_ino_file"`" "$expected_output"


#-Tests-End-------------------------------------#


exit 0
