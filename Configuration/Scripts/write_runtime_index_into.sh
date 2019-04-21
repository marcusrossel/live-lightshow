#!/bin/bash

# This script writes the runtime-index, corresponding to a configuration specified by the user, into
# a given file.
#
# Arguments:
# * <target file>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the user chose to quit
# 3: internal error


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting, lookup and index utilities.
. "$dot/../../Utilities/scripting.sh"
. "$dot/../../Utilities/lookup.sh"
. "$dot/../../Utilities/index.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly target_file=$1
   readonly user_configuration_file=$(mktemp)
   readonly runtime_config_directory="$dot/../../$(path_for_ runtime-configuration-directory)"

   return 0
}


#-Functions-------------------------------------#


# Opens a given user configuration in vi, and allows the user to edit it. The user will be prompted
# to rewrite the configuration as long as it is malformed. They also have the option to quit.
#
# Argument:
# <user configuration>
#
# Return status:
# 0: success
# 1: the user chose to quit
# 2: internal error
function carry_out_configuration_editing_ {
   # Iterates until the user configuration is valid, or the user quits.
   while true; do
      # Allows the user to edit the user configuration.
      vi "$1"

      # Gets all of the items in the user configuration which are invalid and captures the return
      # status.
      invalid_items=$("$dot/verify_user_configuration.sh" "$1"); local return_status=$?

      # Performs different actions based on the verifier's return status.
      case $return_status in
         # Leaves the while-loop on success.
         0) break ;;

         # TODO: Add proper error messages.
         2) error_message="Malformed instance-identifiers:\n$invalid_items" ;;
         3) error_message="Duplicate instance-identifiers:\n$invalid_items" ;;
         4) error_message="Invalid server-identifiers:\n$invalid_items" ;;

         # Prints an error message and returns on failure if any other error occured.
         *) echo "Internal error: \`${BASH_SOURCE[0]}\`" >&2
            return 2 ;;
      esac

      # This point is only reached if a recoverable error occured.
      # Prints an error message and prompts the user for reconfiguration or exit.
      clear >&2
      echo -e "$error_message" >&2
      echo -e "\n${print_green}Do you want to try again? [y or n]$print_normal" >&2
      succeed_on_approval_ || return 1
   done

   return 0
}

# Prints a template which can be displayed to the user when retrieving their desired instance-ID to
# server-type(server ID) mapping.
function user_configuration_template {
   # Prints the user configuration template header.
   echo "$(text_for_ uct-template)"

   # Prints the server-identifiers contained in static index in the form:
   # # * <server ID 1>
   # # * <server ID 2>
   # ...
   column_for_ server-id --in static-index | while read server_id; do
      echo "# * $server_id"
   done

   # Adds a trailing newline.
   echo
   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 1 '<target file>' || exit 1
declare_constants "$@"

# Makes sure the temporary configuration file is cleaned up on exit.
trap "silently- rm '$user_configuration_file'" EXIT

# Sets up the user configuration file.
user_configuration_template >"$user_configuration_file"

carry_out_configuration_editing_ "$user_configuration_file" || exit $(($?+1))

# Empties the target file.
>"$target_file"

# Iterates over the entries in the user configuration.
instance_counter=0
while read -r configuration_entry; do
   # Goes to the next entry if the current one is empty or starts with a #.
   egrep -q '(^$|^\s*#)' <<< "$configuration_entry" && continue

   # Creates clean components from the user configuration entry (removing spaces).
   instance_id=$(echo "$configuration_entry" | cut -d : -f 1 | trimmed)
   server_id=$(echo "$configuration_entry" | cut -d : -f 2 | trimmed)

   # Completes and writes the entry to the target file, and increments the instance counter.
   echo "$instance_id:$server_id:$runtime_config_directory/$instance_counter" >>"$target_file"
   ((instance_counter++))
done < "$user_configuration_file"

exit 0
