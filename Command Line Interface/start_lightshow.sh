#!/bin/bash

# This script gets parameters needed to and starts the lightshow-program.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the user chose to quit
# 3: internal error


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
   readonly arduino_port=$("$dot/arduino_trait.sh" --port); [ $? -eq 3 ] && exit 1

   readonly program_folder="$dot/../../$(path_for_ lightshow-directory)"
   readonly id_class_map="$dot/../../$(path_for_ server-id-class-map)"
   readonly instance_type_map="$dot/../../$(path_for_ server-instance-type-map)"
   readonly instance_config_file_map="$dot/../../$(path_for_ server-instance-config-file-map)"
}


#-Functions-------------------------------------#

# Opens the instance-type map in Vi, and allows the user to edit it. The user will be prompted to
# rewrite the configuration as long as it is malformed. They also have the option to quit.
#
# Return status:
# 0: success
# 1: the user chose to quit
# 2: internal error
function carry_out_configuration_editing_ {
   # Iterates until the instance type map contains a valid configuration, or the user quits.
   while true; do
      # Allows the user to edit to specify the instance-type map.
      vi "$instance_type_map"

      # Gets all of the items in the instance type map which are invalid and captures the return
      # status.
      local error_items=$("$dot/../Configuration/assert_instance_type_map_validity.sh")
      local return_status=$?

      case $? in
         # Leaves the while-loop on success.
         0) break ;;

         # TODO: Add proper error messages.
         2) error_message="Malformed instance-identifiers\n$error_items" ;;
         3) error_message="Duplicate instance-identifiers:\n$error_items" ;;
         4) error_message="Invalid server-identifiers:\n$error_items" ;;

         # Prints an error message and returns on failure if any other error occured.
         *) echo "Internal error: \`${BASH_SOURCE[0]}\`"
            return 2 ;;
      esac

      # This point is only reached if there was a recoverable error.
      clear
      echo -e "$error_message"
      echo -e "${print_green}Do you want to try again? [y or n]$print_normal"
      succeed_on_approval_ || return 1
   done

   return 0
}

# Prints a list of the classes that should be instantiated in the main program.
# Items can occur multiple times, which implies that they should be instantiated multiple times.
function class_instantiation_list {
   local -r server_types=$(cut -d : -f 2 "$instance_type_map")

   while read server_type; do
      local -r cleaned_server_type=$(awk '{$1=$1;print}' <<< "$server_type")
      local -r id_class_map_entry=$(fgrep "$cleaned_server_type:" "$id_class_map")
      local -r class_name=$(cut -d : -f 2 <<< "$id_class_map_entry")

      # No quotes to remove leading or trailing whitespace.
      echo $class_name
   done
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Generates configuration files.
"$dot/../Configuration/id_class_map.sh" >"$id_class_map"
"$dot/../Configuration/instance_type_map_template.sh" >"$instance_type_map"


# Allows the user to setup the program configuration.
carry_out_configuration_editing_ || exit $(($?+1))

# Generates the instance-configuration-file map for the specified instances.
"$dot/../Configuration/instance_configuration_file_map.sh" >"$instance_config_file_map"
# Populates the instance's configuration files with their hardcoded values.
# TODO: Implement.

# Gets a list of the classes that should be instantiated in the main program.
readonly instantiation_list=$(class_instantiation_list)

# Starts the lightshow program, while passing it the Arduino's port and the location of the runtime
# configuration file.
silently- processing-java --sketch="$program_folder" --run "$arduino_port" "$configuration_file" &
