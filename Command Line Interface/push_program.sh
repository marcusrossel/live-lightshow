#!/bin/bash

# This script compiles and uploads the current program to a connected Arduino. If there are no, or
# multiple Arduinos attached, the user will be prompted to fix the issue until there is only one.
# They also have the option to quit.
#
# Arguments:
# * <program directory> optional, defaults to the firmata program folder as specified by
#                                 <lookup file: file locations>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the user chose to quit


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports lookup and utilities.
. "$_dot/../Utilities/lookup.sh"
. "$_dot/../Utilities/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   # Sets the location of the folder holding the program file(s) as the first command line argument,
   # or to the firmata program folder as specified by <lookup file: file locations> if none was
   # passed.
   if [ -n "$1" ]; then
      readonly program_directory=${1%/}
   else
      readonly program_directory="$dot/../../$(path_of_ firmata-directory)"
   fi
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Gets the Arduino's FQBN and port, and exits if the user chose to quit in the process.
traits=$("$dot/arduino_trait.sh" --fqbn --port); [ $? -eq 3 ] && exit 2
readonly arduino_fqbn=$(read <<< "$traits")
readonly arduino_port=$(read <<< "$traits")

# Compiles and uploads the program to the Arduino.
silently- arduino-cli compile --fqbn "$arduino_fqbn" "$program_directory"
silently- arduino-cli upload -p "$arduino_port" --fqbn "$arduino_fqbn" "$program_directory"

exit 0
