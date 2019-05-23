#!/bin/bash

# This script scans a given runtime configuration, asserting the validity of each entry based on a
# given server-ID.
# Runtime configurations have the form:
# <trait 1 ID>:<trait 1 value>:<trait 1 type>
# <trait 2 ID>:<trait 2 value>:<trait 1 type>
# ...
#
# A trait-ID must appear in the static configuration associated with the given server-ID. A trait-ID
# must also not be declared more than once.
# A trait-value must match its trait type.
#
# If any aspect is invalid, it is printed with the script returning on an associated return status.
# If multiple aspects are invalid, only one of them will be printed.
# Validity aspects are checked in the order:
# * trait-ID validity
# * trait-ID uniqueness
# * trait-value type correctness
#
# Arguments:
# * <runtime configuration>
# * <server id>
#
# Return status:
# 0: success
# 1: invalid number of arguments
# 2: <runtime configuration file> contains malformed entries
# 3: <runtime configuration file> contains invalid trait-identifiers
# 4: <runtime configuration file> contains duplicate trait-declarations
# 5: <runtime configuration file> contains invalid trait-values


#-Preliminaries---------------------------------#


# Gets the directory of this script and imports utilities.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"
. "$dot/../../../Utilities/parsing.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly static_config_file=$(fields_for_ config-file --with server-name "$2" --in static-index)
   return 0
}


#-Functions-------------------------------------#


# Prints a list of the invalid trait IDs contained in given runtime configuration entries.
#
# Arguments:
# * <runtime configuration entries>
function invalid_trait_identifiers_in {
   # Gets lists of the given trait-IDs and valid trait-IDs.
   local -r given_trait_ids=$(data_for_ trait-name --in runtime-config --entries "$1")
   local -r valid_trait_ids=$(data_for_ trait-name --in static-config "$static_config_file")

   # Iterates over the given trait-IDs.
   while read -r given_trait_id; do
      # Prints the given trait-ID, if it is not contained in the list of valid trait-IDs.
      if [ -z "$given_trait_id" ]; then
         echo ' '
      elif ! $(string_ "$given_trait_id" --is-line-in-string "$valid_trait_ids"); then
         echo "$given_trait_id"
      fi
   done <<< "$given_trait_ids"

   return 0
}

# Prints a list of the duplicate trait-IDs contained in given runtime configuration entries.
#
# Arguments:
# * <runtime configuration entries>
function duplicate_trait_identifiers_in {
   # Creates a map of <count>:<trait-ID>.
   local -r trait_ids=$(data_for_ trait-name --in runtime-config --entries "$1")
   local -r count_id_map=$(echo "$trait_ids" | sort | uniq -c | sed -e 's/^ *//;s/ /:/')

   # Iterates over the <count>:<trait-ID> map.
   while read -r count_id; do
      local count=$(cut -d : -f 1 <<< "$count_id")

      # Prints the trait-ID if appears multiple times.
      [ "$count" -gt 1 ] && echo "$(cut -d : -f 2- <<< "$count_id")"
   done <<< "$count_id_map"

   return 0
}

# Prints a list of trait values with non-matching expected type contained in given runtime
# configuration entries.
#
# Arguments:
# * <runtime configuration entries>
function malformed_trait_values_in {
   # Iterates over the list of given configuration entries.
   while read entry; do
      # Extracts the parameters from the entry.
      local trait_id=$(data_for_ trait-name --in runtime-config --entries "$entry")
      local trait_value=$(data_for_ trait-value --in runtime-config --entries "$entry")

      local expected_value_type=$(echo "$entry" | rev | cut -d : -f 1 | rev)

      # Gets the type of the trait value.
      local value_type=$(type_for_value_ "$trait_value")

      # Prints a expected type value pair if it does not match.
      [ "$value_type" != "$expected_value_type" ] && echo "$expected_value_type:$trait_value"
   done <<< "$1"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 2 '<runtime configuration> <server ID>' || exit 1
declare_constants "$@"

# Asserts trait-ID validity.
readonly invalid_trait_ids=$(invalid_trait_identifiers_in "$1")
[ -z "$invalid_trait_ids" ] || { echo "$invalid_trait_ids"; exit 2; }

# Asserts trait-ID uniqueness.
readonly duplicate_trait_ids=$(duplicate_trait_identifiers_in "$1")
[ -z "$duplicate_trait_ids" ] || { echo "$duplicate_trait_ids"; exit 3; }

# Asserts trait-value type correctness.
readonly malformed_trait_values=$(malformed_trait_values_in "$1")
[ -z "$malformed_trait_values" ] || { echo "$malformed_trait_values"; exit 4; }

exit 0
