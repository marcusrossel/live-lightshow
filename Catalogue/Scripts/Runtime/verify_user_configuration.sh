#!/bin/bash

# This script scans a given user configuration, asserting the validity of each entry.
# User configurations have the form:
# <unique instance-ID 1>:<server-ID 1>
# <unique instance-ID 2>:<server-ID 2>
# ...
#
# A server-ID must appear in the current static index.
#
# If any aspect is invalid, it is printed with the script returning on an associated return status.
# If multiple aspects are invalid, only one of them will be printed.
# Validity aspects are checked in the order:
# * instance-ID uniqueness
# * server-ID validity
#
# Arguments:
# * <user configuration>
#
# Return status:
# 0: success
# 1: invalid number of arguments
# 2: <user configuration> contains duplicate instance-identifiers
# 3: <user configuration> contains invalid server-identifiers


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"


#-Functions-------------------------------------#


# Prints a list of the duplicate instance IDs contained in given user configuration entries.
#
# Arguments:
# * <user configuration entries>
function duplicate_instance_identifiers_in {
   # Creates a map of <count>:<instance ID>.
   local -r count_id_map=$(cut -d : -f 1 <<< "$1" | sort | uniq -c | sed -e 's/^ *//;s/ /:/')

   # Iterates over the <count>:<instance ID> map.
   while read -r count_id; do
      local count=$(cut -d : -f 1 <<< "$count_id")

      # Prints the instance ID if appears multiple times.
      [ "$count" -gt 1 ] && echo "$(cut -d : -f 2- <<< "$count_id")"
   done <<< "$count_id_map"

   return 0
}

# Prints a list of the invalid server IDs contained in given user configuration entries.
#
# Arguments:
# * <user configuration entries>
function invalid_server_identifiers_in {
   # Gets a list of the valid server IDs.
   local -r valid_server_ids=$(data_for_ server-name --in static-index)

   # Iterates over the given entries.
   while read -r entry; do
      # Extracts the server-ID from the current entry.
      local server_id=$(echo "$entry" | cut -d : -f 2- | trimmed)

      # Prints the given server ID, if it is not contained in the list of valid types.
      if [ -z "$server_id" ]; then
         echo ' '
      elif ! $(string_ "$server_id" --is-line-in-string "$valid_server_ids"); then
         echo "$server_id"
      fi
   done <<< "$1"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 1 '<user configuration>' || exit 1

# Asserts instance-ID uniqueness.
readonly duplicate_instance_ids=$(duplicate_instance_identifiers_in "$1")
[ -z "$duplicate_instance_ids" ] || { echo "$duplicate_instance_ids"; exit 2; }

# Asserts server-ID validity.
readonly invalid_server_ids=$(invalid_server_identifiers_in "$1")
[ -z "$invalid_server_ids" ] || { echo "$invalid_server_ids"; exit 3; }

exit 0
