#!/bin/bash

# This script allows the user to edit the runtime configuration file associated with a given server
# instance identifier.
#
# Arguments:
# * <server instance identifier>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: invalid <server instance>
# 3: the user chose to quit


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants_ {
   # Gets the server name associated with the given <server instance identifier>, or returns on
   # failure if none was found.
   readonly server_id=$(fields_for_ server-name --with instance-name "$1" --in runtime-index)
   if [ -z "$server_id" ]; then
      # TODO: Figure out a general strategy for hiding errors messages while showing user-data.
      # print_error_for "Script received invalid server instance identifier" \
      #                 "'$print_yellow$1$print_normal'."
      return 1
   fi

   # Gets the runtime configuration file associated with the given <server instance identifier>.
   readonly runtime_config_file=$(
      fields_for_ config-file --with instance-name "$1" --in runtime-index
   )

   return 0
}


#-Functions-------------------------------------#


# Prints a server-ID specific header meant to be placed at the top of a runtime configuration file.
#
# Arguments:
# * <server ID>
function header_for_server_id {
   # Gets the list of valid trait IDs.
   local -r static_config_file=$(
      fields_for_ config-file --with server-name "$server_id" --in static-index
   )

   local -r valid_trait_ids=$(data_for_ trait-name --in static-config "$static_config_file")

   # Prints the header.
   echo "$(text_for_ csi-header)"
   while read valid_trait_id; do
      echo "# • $valid_trait_id"
   done <<< "$valid_trait_ids"

   # Adds a trailing newline.
   echo

   return 0
}

# Opens a given runtime configuration in vi, and allows the user to edit it. The user will be
# prompted to rewrite the configuration as long as it is malformed. They also have the option to
# quit.
#
# Argument:
# <runtime configuration file>
#
# Return status:
# 0: success
# 1: the user chose to quit
# 2: internal error
function carry_out_configuration_editing_ {
   # Iterates until the configuration is valid, or the user quits.
   while true; do
      # Allows the user to edit the runtime configuration.
      vi "$1"

      # Creates a cleaned version of the user-edited runtime configuration.
      local clean_configuration=$(cleaned_configuration "$1")

      # Gets all of the items in the configuration which are invalid and captures the return status.
      local invalid_items;
      invalid_items=$("$dot/verify_runtime_configuration.sh" "$clean_configuration" "$server_id")

      # Performs different actions based on the verifier's return status.
      case $? in
         # Writes the cleaned configuration into the runtime configuration file and leaves the
         # while-loop.
         0) echo "$clean_configuration" >"$1"; break ;;

         # Sets an appropriate error message if a recoverable error occurs.
         2)
         local error_message=$(text_for_ csi-invalid-trait-names)
         while read -r invalid_id; do
            error_message="$error_message${newline}• '$print_yellow$invalid_id$print_normal'"
         done <<< "$invalid_items" ;;

         3)
         local error_message=$(text_for_ csi-duplicate-trait-names)
         while read -r duplicate_id; do
            error_message="$error_message${newline}• '$print_yellow$duplicate_id$print_normal'"
         done <<< "$invalid_items" ;;

         4)
         local error_message=$(text_for_ csi-invalid-trait-values)
         while read -r type_value_pair; do
            local expected_type=$(pretty_printed_type_ "$(cut -d : -f 1 <<< "$type_value_pair")")
            local value=$(cut -d : -f 2- <<< "$type_value_pair")
            error_message="$error_message${newline}• '$print_yellow$value$print_normal'"
            error_message="$error_message expected $print_yellow$expected_type$print_normal"
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

# Prints a pretty string representation of a given type.
#
# Arguments:
# * <type> possible values: "int", "float", "bool", "int-list", "float-list", "bool-list"
#
# Return status:
# 0: success
# 1: <type> was not valid
function pretty_printed_type_ {
   case "$1" in
      # Primitive types.
      int)   echo 'Integer' ;;
      float) echo 'Float' ;;
      bool)  echo 'Boolean' ;;

      # List types.
      int-list|float-list|bool-list)
         local -r subtype_identifier=$(cut -d '-' -f 1 <<< "$1")
         echo "$(pretty_printed_type_ "$subtype_identifier")-List" ;;

      # Invalid type identifiers.
      *) print_error_for_ --internal; return 1 ;;
   esac

   return 0
}

# Takes a given user-edited runtime-configuration file and prints the corresponding cleaned runtime-
# configuration.
#
# Arguments:
# * <user-edited runtime-configuration file>
function cleaned_configuration {
   # Gets constants needed in this function.
   local -r trait_id_column=$(data_for_ trait-name --in runtime-config "$runtime_config_file")

   # Strips all of the empty lines and those starting with #.
   # Then removes all leading and trailing whitespace from the entry's components and appends the
   # proper value type at the end.
   # If an entry does not contain any : character, one is added after the raw entry.
   while read entry; do
      egrep -q '(^\s*$|^\s*#)' <<< "$entry" && continue

      if [ "$(awk -F : '{print NF-1}' <<< "$entry")" -eq 0 ]; then
         entry="$entry:"
      fi

      local trait_id=$(echo "$entry" | cut -d : -f 1 | trimmed)
      local trait_value=$(echo "$entry" | cut -d : -f 2- | trimmed)

      local trait_entry_line=$(line_numbers_of_string_ "$trait_id" --in-string "$trait_id_column")

      # If no trait entry line is found, the identifier is malformed, so a dummy type is appended.
      if [ -z "$trait_entry_line" ]; then
         local trait_type='unknown'
      else
         local trait_entry=$(line_ "$trait_entry_line" --in-file "$runtime_config_file")
         local trait_type=$(data_for_ trait-type --in runtime-config --entries "$trait_entry")
      fi

      # Prints the cleaned entry.
      echo "$trait_id:$trait_value:$trait_type"
   done < "$1"
}

#-Main------------------------------------------#

# TODO: Figure out a general strategy for hiding errors messages while showing user-data.
assert_correct_argument_count_ 1 '<server instance identifier>' &>/dev/null || exit 1
declare_constants_ "$@" || exit 2

# Creates a working copy of the runtime configuration file, and makes sure it is removed upon
# exiting.
readonly configuration_copy=$(mktemp)
trap "silently- rm '$configuration_copy'" EXIT

# Initializes the copy of the configuration.
header_for_server_id "$server_id" > "$configuration_copy"
while read entry; do
   trait_id=$(data_for_ trait-name --in runtime-config --entries "$entry")
   trait_value=$(data_for_ trait-value --in runtime-config --entries "$entry")
   echo "$trait_id: $trait_value" >> "$configuration_copy"
done < "$runtime_config_file"

# Performs editing on the configuration copy.
carry_out_configuration_editing_ "$configuration_copy" || exit $(($?+1))

# Writes the result back into the original runtime configuration.
cat "$configuration_copy" >"$runtime_config_file"

exit 0
