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
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/catalogue.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly target_file=$1
   readonly user_configuration_file=$(mktemp)
   readonly runtime_data_directory=$(realpath "$dot/../../../$(path_for_ runtime-data-directory)")

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

      # Creates a cleaned version of the user-edited runtime configuration.
      local clean_configuration=$(cleaned_configuration "$1")

      # Gets all of the items in the user configuration which are invalid and captures the return
      # status.
      local invalid_items
      invalid_items=$("$dot/verify_user_configuration.sh" "$clean_configuration")

      # Performs different actions based on the verifier's return status.
      case $? in
         # Writes the cleaned configuration into the user configuration file and leaves the while-
         # loop.
         0) echo "$clean_configuration" >"$1"; break ;;

         # Sets an appropriate error message if a recoverable error occurs.
         2)
         local error_message=$(text_for_ wrii-duplicate-instance-names)
         while read -r duplicate_id; do
            error_message="$error_message${newline}• '$print_yellow$duplicate_id$print_normal'"
         done <<< "$invalid_items" ;;

         3)
         local error_message=$(text_for_ wrii-invalid-server-names)
         while read -r invalid_server_id; do
            error_message="$error_message${newline}• '$print_yellow$invalid_server_id$print_normal'"
         done <<< "$invalid_items" ;;

         # Prints an error message and returns on failure if any other error occured.
         *) print_error_for --internal; return 2 ;;
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
   echo "$(text_for_ wrii-header)"

   # Prints the server-identifiers contained in static index in the form:
   # # • <server ID 1>
   # # • <server ID 2>
   # ...
   data_for_ server-name --in static-index | while read -r server_id; do
      echo "# • $server_id"
   done

   # Adds a trailing newline.
   echo
   return 0
}

# Takes a given user configuration file and prints the corresponding cleaned user configuration.
#
# Arguments:
# * <user configuration file>
function cleaned_configuration {
   # Strips all of the empty lines and those starting with #.
   # Then removes all leading and trailing whitespace from the entry's components.
   # If an entry does not contain any : character, one is added at the end.
   while read entry; do
      # TEMP
      egrep -q '(^\s*$|^\s*#)' <<< "$entry" && continue

      if [ "$(awk -F : '{print NF-1}' <<< "$entry")" -eq 0 ]; then
         entry="$entry:"
      fi

      local instance_id=$(echo "$entry" | cut -d : -f 1 | trimmed)
      local server_id=$(echo "$entry" | cut -d : -f 2- | trimmed)

      # Prints the cleaned entry.
      echo "$instance_id:$server_id"
   done <"$1"
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
echo -n >"$target_file"

# Iterates over the entries in the user configuration.
instance_counter=0
while read -r configuration_entry; do
   # Completes and writes the entry to the target file, and increments the instance counter.
   echo "$configuration_entry:$runtime_data_directory/$instance_counter" >>"$target_file"
   ((instance_counter++))
done <"$user_configuration_file"

exit 0
