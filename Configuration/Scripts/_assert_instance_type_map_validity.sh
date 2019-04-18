#!/bin/bash

# This script scans a given instance-type map, asserting the validity of each entry.
# Instance-type maps have the form:
# <unique instance-ID 1>: <server-ID 1>
# <unique instance-ID 2>: <server-ID 2>
# ...
#
# An instance-ID may not contain the characters " and : and each ID must be unique.
# A server-ID must appear in the given ID-class map.
#
# If any aspect is invalid, it is printed with the script returning on an associated return status.
# If multiple aspects are invalid, only one of them will be printed.
# Validity aspects are checked in the order:
# * instance-ID wellformedness
# * instance-ID uniqueness
# * server-ID validity
#
# Arguments:
# * <instance-type map> optional, for testing purposes
# * <server id-class map> optional, for testing purposes
#
# Return status:
# 0: success
# 1: invalid number of arguments
# 2: <instance-type map> contains malformed instance-identifiers
# 3: <instance-type map> contains duplicate instance-identifiers
# 4: <instance-type map> contains invalid server types


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
   # Sets the location of the <instance-type map> as the first command line argument, or to the one
   # specified by <lookup file: file paths> if none was passed.
   if [ -n "$1" ]; then
      readonly instance_type_map=$1
   else
      readonly instance_type_map="$dot/../../$(path_for_ server-instance-type-map)"
   fi

   # Sets the location of the <id-class map> as the second command line argument, or to the one
   # specified by <lookup file: file paths> if none was passed.
   if [ -n "$2" ]; then
      readonly id_class_map=$2
   else
      readonly id_class_map="$dot/../../$(path_for_ server-id-class-map)"
   fi
}


#-Functions-------------------------------------#


# Prints a list of the malformed instance-identifiers contained in <instance-type-map>.
function malformed_instance_identifiers {
   # Gets lists of the identifiers and the pattern they need to match.
   local -r identifiers=$(cut -d : -f 1 "$instance_type_map")
   local -r identifier_pattern='(^#)|(^[^:"]+$)'

   # Prints all of the identifiers not conforming to the required pattern.
   egrep -v "$identifier_pattern" <<< "$identifiers"

   return 0
}

# Prints a list of the duplicate instance-identifiers contained in <instance-type-map>.
function duplicate_instance_identifiers {
   # Gets lists of the identifiers and the pattern they need to match.
   local -r identifiers=$(cut -d : -f 1 "$instance_type_map")

   # Iterates over a map of <count>: <identifier>.
   sort <<< "$identifiers" | uniq -c | while read count_identifier; do
      local count=$(tr -s ' ' <<< "$count_identifier" | cut -d ' ' -f 1)

      # Prints the identifier if it is a duplicate.
      if [ "$count" -gt 1 ]; then
         local duplicate=$(tr -s ' ' <<< "$count_identifier" | cut -d ' ' -f 2)
         echo "$duplicate"
      fi
   done

   return 0
}

# Prints a list of the invalid server types contained in <instance-type-map>.
function invalid_server_types {
   # Gets lists of the given and valid server IDs (aka types).
   local -r given_types=$(cut -d : -f 2 "$instance_type_map")
   local -r valid_types=$(cut -d : -f 1 "$id_class_map")

   while read given_type; do
      # Removes leading and trailing whitespace from the given type.
      local cleaned_given_type=$(awk '{$1=$1};1' <<< "$given_type")

      # Prints the given type, if it is not contained in the list of valid types.
      if ! fgrep -q "$cleaned_given_type" <<< "$valid_types"; then
         echo "$cleaned_given_type"
      fi
   done <<< "$given_types"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 2 '<instance-type map: optional>' || exit 1
declare_constants "$@"

# Asserts instance-ID wellformedness.
readonly malformed_IDs=$(malformed_instance_identifiers)
[ -z "$malformed_IDs" ] || { echo "$malformed_IDs"; exit 2; }

# Asserts instance-ID uniqueness.
readonly duplicate_IDs=$(duplicate_instance_identifiers)
[ -z "$duplicate_IDs" ] || { echo "$duplicate_IDs"; exit 3; }

# Asserts server-ID validity.
readonly invalid_servers=$(invalid_server_types)
[ -z "$invalid_servers" ] || { echo "$invalid_servers"; exit 4; }

exit 0
