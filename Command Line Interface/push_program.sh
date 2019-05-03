#!/bin/bash

# This script compiles and uploads the current program to a connected Arduino. If there are no, or
# multiple Arduinos attached, the user will be prompted to fix the issue until there is only one.
# They also have the option to quit.
#
# Arguments:
# * <program directory> optional, defaults to the firmata program folder as specified by
#                                 <lookup file: file paths>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the user chose to quit
# 3: the <program directory> could not be compiled or uploaded


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../Utilities/scripting.sh"
. "$dot/../Utilities/lookup.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   # Sets the location of the folder holding the program file(s) as the first command line argument,
   # or to the firmata program folder as specified by <lookup file: file paths> if none was passed.
   if [ -n "$1" ]; then
      readonly program_folder=${1%/}
   else
      readonly program_folder="$dot/../../$(path_for_ firmata-directory)"
   fi
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 1 '<program directory: optional>' || exit 1
declare_constants "$@"

# Gets the Arduino's FQBN and port, or exits if the user chose to quit in the process.
traits=$("$dot/arduino_trait.sh" --fqbn --port); [ $? -eq 3 ] && exit 2
readonly arduino_fqbn=$(line_ 1 --in-string "$traits")
readonly arduino_port=$(line_ 2 --in-string "$traits")

# Compiles and uploads the program to the Arduino.
silently- arduino-cli compile --fqbn "$arduino_fqbn" "$program_folder" || exit 3
silently- arduino-cli upload -p "$arduino_port" --fqbn "$arduino_fqbn" "$program_folder" || exit 3

exit 0
