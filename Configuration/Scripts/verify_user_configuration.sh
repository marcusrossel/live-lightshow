#!/bin/bash

# This script scans a given user configuration, asserting the validity of each entry.
# User configurations have the form:
# <unique instance-ID 1>: <server-ID 1>
# <unique instance-ID 2>: <server-ID 2>
# ...
#
# An instance-ID may not contain the characters " and : and each ID must be unique.
# A server-ID must appear in the current static index.
# Lines starting with # are ignored.
#
# If any aspect is invalid, it is printed with the script returning on an associated return status.
# If multiple aspects are invalid, only one of them will be printed.
# Validity aspects are checked in the order:
# * instance-ID wellformedness
# * instance-ID uniqueness
# * server-ID validity
#
# Arguments:
# * <user configuration>
#
# Return status:
# 0: success
# 1: invalid number of arguments
# 2: <user configuration> contains malformed instance-identifiers
# 3: <user configuration> contains duplicate instance-identifiers
# 4: <user configuration> contains invalid server-identifiers


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting and lookup utilities.
. "$dot/../../Utilities/scripting.sh"
. "$dot/../../Utilities/lookup.sh"
. "$dot/../../Utilities/index.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly static_index="$dot/../../$(path_for_ static-index)"
   readonly server_id_column=$(column_number_for_ server-id --in static-index)
}


#-Functions-------------------------------------#


# Prints a list of the malformed instance IDs contained in given user configuration entries.
#
# Arguments:
# * <user configuration entries>
function malformed_instance_identifiers_in {
   # Gets lists of the instance IDs and the pattern they need to match.
   local -r instance_ids=$(cut -d : -f 1 <<< "$1")
   local -r instance_ids_pattern='(^#)|(^[^:"]+$)'

   # Prints all of the instance IDs not conforming to the required pattern.
   egrep -v "$instance_ids_pattern" <<< "$instance_ids"

   return 0
}

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
   # Gets lists of the given and valid server IDs.
   local -r given_server_ids=$(cut -d : -f 2- <<< "$1")
   local -r valid_server_ids=$(cut -d : -f "$server_id_column" "$static_index")

   # Iterates over the given server IDs.
   while read -r given_server_id; do
      # Removes leading and trailing whitespace from the given server ID.
      local cleaned_given_server_id=$(awk '{$1=$1};1' <<< "$given_server_id")

      # Prints the given server ID, if it is not contained in the list of valid types.
      if ! fgrep -q "$cleaned_given_server_id" <<< "$valid_server_ids"; then
         echo "$cleaned_given_server_id"
      fi
   done <<< "$given_server_ids"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 1 '<user configuration>' || exit 1
declare_constants "$@"

# Gets the lines that are not empty and don't start with #.
readonly configuration_entries=$(egrep -v '(^$|^\s*#)' "$1")

# Asserts instance-ID wellformedness.
readonly malformed_instance_ids=$(malformed_instance_identifiers_in "$configuration_entries")
[ -z "$malformed_instance_ids" ] || { echo "$malformed_instance_ids"; exit 2; }

# Asserts instance-ID uniqueness.
readonly duplicate_instance_ids=$(duplicate_instance_identifiers_in "$configuration_entries")
[ -z "$duplicate_instance_ids" ] || { echo "$duplicate_instance_ids"; exit 3; }

# Asserts server-ID validity.
readonly invalid_server_ids=$(invalid_server_identifiers_in "$configuration_entries")
[ -z "$invalid_server_ids" ] || { echo "$invalid_server_ids"; exit 4; }

exit 0