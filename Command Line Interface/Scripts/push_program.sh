#!/bin/bash

# This script compiles and uploads the current program to a connected Arduino. If there are no, or
# multiple Arduinos attached, the user will be prompted to fix the issue until there is only one.
# They also have the option to quit.
#
# Arguments:
# * <program directory> optional, for testing purposes

# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: internal error
# 3: the user chose to quit


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports CLI utilities.
. "$_dot/../Libraries/utilities.sh"
. "$_dot/../Libraries/constants.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   # Sets the location of the folder holding the program file(s) as the first command line
   # argument, or to the one specified by <utility file: file locations> if none was passed.
   if [ -n "$1" ]; then
      readonly program_folder=${1%/}
   else
      readonly program_folder="$dot/../../`location_of_ --repo-program-directory`"
   fi

   # Creates a file in which errors can be collected.
   readonly error_pool=`mktemp`
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1 #RS=1
declare_constants "$@"

# Makes sure the temporary files are removed on exiting.
trap "rm '$error_pool'" EXIT

# Loops until there is exactly on Arduino connected or the user quits.
while true; do
   # Gets the Arduino's FQBN and port, while saving any error messages.
   arduino_fqbn=`"$dot/arduino_trait.sh" --fqbn 2>"$error_pool"`
   arduino_port=`"$dot/arduino_trait.sh" --port 2>"$error_pool"`

   case $? in
      # Breaks out of the loop if the operation was successful.
      0) break ;;

      # Sets an appropriate error-message if the operation failed on a recoverable error.
      3) error_message=`message_for_ --ct-no-arduino` ;;
      4) error_message=`message_for_ --ct-multiple-arduinos` ;;

      # Prints an error message and returns on failure if any other error occured.
      *) echo 'Internal error:'; cat "$error_pool"; exit 2 ;; #RS=2
   esac

   # This point is only reached if a recoverable error occured.
   # Prints an error message and prompts the user to un-/replug the Arduino or exit.
   clear
   echo -e "$error_message"
   echo -e "\n${print_green}Do you want to try again? [y or n]$print_normal"
   succeed_on_approval_ || exit 3 #RS=3
done

# Compiles and uploads the program to the Arduino.
silently- arduino-cli compile --fqbn "$arduino_fqbn" "$program_folder"
silently- arduino-cli upload -p "$arduino_port" --fqbn "$arduino_fqbn" "$program_folder"

exit 0
