#!/bin/bash

# This script pulls a threshold-configuration from the `.ino`-file in the CLI-directory, lets the
# user configure it, and applies the changes to the `.ino`-file.
# If the user creates a malformed configuration, they are prompted to rewrite it or quit.
#
# Expectations:
# * there is exactly one file ending on ".ino" in the parent directory of this script
#
# Arguments:
# * <program directory> optional, for testing purposes
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: internal error
# 3: the user chose to quit the program


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

   # Gets the program file, which should be the only file in the program-folder ending in ".ino".
   readonly program_file="$program_folder/`ls -1 "$program_folder" | egrep '\.ino$'`"
   # Creates a file in which the configuration can be saved.
   readonly configuration_file=`mktemp`
   # Creates a file in which errors can be collected.
   readonly error_pool=`mktemp`
}


#-Functions-------------------------------------#


# Opens the configuration file in Vi, and allows the user to edit it. The user will be prompted to
# rewrite the configuration as long as it is malformed. They also have the option to quit.
#
# Return status:
# 0: success
# 1: internal error
# 2: the user chose to quit
function carry_out_configuration_editing_ {
   # Loops until the specified configuration is valid or the user quits.
   while true; do
      # Opens the configuration in Vi to allow the user to edit it.
      vi "$configuration_file"

      # Tries to apply the user-specified configuration to the program file, while saving any error
      # messages.
      "$dot/apply_configuration.sh" "$configuration_file" "$program_file" 2>"$error_pool"

      # Checks the success of the previous operation.
      case $? in
         # Breaks out of the loop if the operation was successful.
         0) break ;;

         # Sets an appropriate error-message if the operation failed on a recoverable error.
         3) error_message=`message_for_ --ct-malformed-configuratation` ;;
         4) error_message=`message_for_ --ct-duplicate-identifiers` ;;

         # Prints an error message and returns on failure if any other error occured.
         *) echo 'Internal error:'; cat "$error_pool"; return 1 ;;
      esac

      # This point is only reached if a recoverable error occured.
      # Prints an error message and prompts the user for reconfiguration or exit.
      clear
      echo -e "$error_message"
      echo -e "\n${print_green}Do you want to try again? [y or n]$print_normal"
      succeed_on_approval_ || return 2
   done

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 1 '<program folder: optional>' || exit 1 #RS=1
declare_constants "$@"

# Makes sure the temporary files are removed on exiting.
trap "rm '$configuration_file' '$error_pool'" EXIT

# Tries to get the threshold-configuration of the program file, while saving any error messages. If
# that fails, an error message is printed and a return on failure occurs.
if ! "$dot/threshold_configuration.sh" "$program_file" >"$configuration_file" 2>"$error_pool"; then
   echo 'Internal error:'; cat "$error_pool"
   exit 2 #RS=2
fi

carry_out_configuration_editing_ || exit $[$?+1] #RS+2=3

# Tries to get the threshold-configuration of the program file, while saving any error messages. If
# that fails, an error message is printed and a return on failure occurs.
"$dot/push_program.sh" 2>"$error_pool"
case $? in
   # Returns successfully if the operation succeeded.
   0) exit 0;;
   # Occurs if the user chose to quit the program.
   3) exit 3 ;; #RS=3
   # Prints an error message and returns on failure if any other error occured.
   *) echo 'Internal error:'; cat "$error_pool"; exit 2 ;; #RS=2
esac
