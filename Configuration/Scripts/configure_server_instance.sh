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
# Imports scripting, lookup and index utilities.
. "$dot/../../Utilities/scripting.sh"
. "$dot/../../Utilities/lookup.sh"
. "$dot/../../Utilities/index.sh"

#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly server_id=$(runtime_ server-id --for instance-id "$1")

   return 0
}


#-Functions-------------------------------------#


# Prints a server-ID specific header meant to be placed at the top of a runtime configuration file.
#
# Arguments:
# * <server ID>
function header_for_server_id {
   # Gets the list of valid trait IDs.
   local -r static_config_file=$(static_ config-file --for server-id "$server_id")
   local -r valid_trait_ids=$(cut -d : -f 1 "$static_config_file")

   # Prints the header.
   echo "$(text_for_ csi-header)"
   while read valid_trait_id; do
      echo "# * $valid_trait_id"
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
      # Allows the user to edit the user configuration.
      vi "$1"

      # Gets all of the items in the configuration which are invalid and captures the return status.
      invalid_items=$("$dot/verify_runtime_configuration.sh" "$1" "$server_id")
      local return_status=$?

      # Performs different actions based on the verifier's return status.
      case $return_status in
         # Leaves the while-loop on success.
         0) break ;;

         # TODO: Add proper error messages.
         2) error_message="Invalid trait-identifiers:\n$invalid_items" ;;
         3) error_message="Duplicate trait-declarations:\n$invalid_items" ;;
         4) error_message="Malformed trait-values:\n$invalid_items" ;;

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


#-Main------------------------------------------#


assert_correct_argument_count_ 1 '<server instance identifier>' || exit 1
declare_constants "$@"

# Gets the runtime configuration file associated with the given <server instance identifier>, or
# returns on failure if none was found.
if ! runtime_config_file=$(runtime_ config-file --for instance-id "$1"); then
   echo "Error: \`${BASH_SOURCE[0]}\` received invalid server instance identifier \"$1\"" >&2
   exit 2
fi

# Creates a working copy of the runtime configuration file, and makes sure it is removed upon
# exiting.
readonly configuration_copy=$(mktemp)
trap "rm '$configuration_copy'" EXIT

# Initializes the copy of the configuration.
header_for_server_id "$server_id" > "$configuration_copy"
cat "$runtime_config_file" >> "$configuration_copy"

# Performs editing on the configuration copy.
carry_out_configuration_editing_ "$configuration_copy" || exit $(($?+1))

# Strips all of the empty lines and those starting with # from the configuration copy.
# Then replaces all occurences of ": " with ":" and writes the result back into the original
# runtime configuration.
egrep -v '(^$|^\s*#)' "$configuration_copy" | sed -e 's/: /:/g' >"$runtime_config_file"

exit 0
