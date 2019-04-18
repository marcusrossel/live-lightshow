#!/bin/bash


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting and testing utilities.
. "$dot/scripting.sh"
. "$dot/testing.sh"


#-Constants-------------------------------------#


readonly test_command="$dot/../Scripts/arduino_trait.sh"


#-Setup-----------------------------------------#


echo "Testing \``basename "$test_command"`\` in \`${BASH_SOURCE##*/}\`:"


#-Tests-Begin-----------------------------------#


# Test: Usage

silently- "$test_command"
report_if_last_status_was 1

silently- "$test_command" 1 2
report_if_last_status_was 1


# Test: Invalid flag

silently- "$test_command" X
report_if_last_status_was 2


# Test: No Arduino
# Condition: No Arduino should be plugged into the computer.

silently- "$test_command" --fqbn
report_if_last_status_was --conditional 3


# Test: Multiple Arduinos
# Condition: Multiple Arduinos should be plugged into the computer.

silently- "$test_command" --fqbn
report_if_last_status_was --conditional 4


#-Tests-End-------------------------------------#


exit 0
