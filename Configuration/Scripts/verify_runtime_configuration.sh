# This script scans a given runtime configuration, asserting the validity of each entry based on a
# given server-ID.
# User runtime configurations have the form:
# <trait 1 ID>: <trait 1 value>
# <trait 2 ID>: <trait 2 value>
# ...
#
# A trait-ID must appear in the static configuration associated with the given server-ID. A trait-ID
# must also not be declared more than once.
# A trait-value must be numeric.
# Lines starting with # are ignored.
#
# If any aspect is invalid, it is printed with the script returning on an associated return status.
# If multiple aspects are invalid, only one of them will be printed.
# Validity aspects are checked in the order:
# * trait-ID validity
# * trait-ID uniqueness
# * trait-value wellformedness
#
# Arguments:
# * <runtime configuration file>
# * <server id>
#
# Return status:
# 0: success
# 1: invalid number of arguments
# 2: <runtime configuration file> contains invalid trait-identifiers
# 3: <runtime configuration file> contains duplicate trait-declarations
# 4: <runtime configuration file> contains malformed trait-values


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
   local -r server_id=$2
   readonly static_config_file=$(values_for_ config-file --in static-index \
                                                      --with server-id "$server_id")
}


#-Functions-------------------------------------#


# Prints a list of the invalid trait IDs contained in given runtime configuration entries.
#
# Arguments:
# * <runtime configuration entries>
function invalid_trait_identifiers_in {
   # Gets lists of the given trait-IDs and valid trait-IDs.
   local -r given_trait_ids=$(cut -d : -f 1 <<< "$1")
   local -r valid_trait_ids=$(cut -d : -f 1 "$static_config_file")

   # Iterates over the given trait-IDs.
   while read -r given_trait_id; do
      # Removes leading and trailing whitespace from the given trait-ID.
      local cleaned_given_trait_id=$(awk '{$1=$1};1' <<< "$given_trait_id")

      # Prints the given trait-ID, if it is not contained in the list of valid trait-IDs.
      if ! fgrep -q "$cleaned_given_trait_id" <<< "$valid_trait_ids"; then
         echo "$cleaned_given_trait_id"
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
   local -r count_id_map=$(cut -d : -f 1 <<< "$1" | sort | uniq -c | sed -e 's/^ *//;s/ /:/')

   # Iterates over the <count>:<trait-ID> map.
   while read -r count_id; do
      local count=$(cut -d : -f 1 <<< "$count_id")

      # Prints the trait-ID if appears multiple times.
      [ "$count" -gt 1 ] && echo "$(cut -d : -f 2- <<< "$count_id")"
   done <<< "$count_id_map"

   return 0
}

# Prints a list of the malformed trait-IDs contained in given runtime configuration entries.
#
# Arguments:
# * <runtime configuration entries>
function malformed_trait_values_in {
   # Gets lists of the trait values and the pattern they need to match.
   local -r trait_values=$(cut -d : -f 2 <<< "$1")
   local -r trait_value_pattern=$(regex_for_ number)

   # Prints all of the trait values not conforming to the required pattern.
   egrep -v "$trait_value_pattern" <<< "$trait_values"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 2 '<runtime configuration file> <server ID>' || exit 1
declare_constants "$@"

# Gets the lines that are not empty and don't start with #.
readonly configuration_entries=$(egrep -v '(^$|^\s*#)' "$1")

# Asserts trait-ID validity.
readonly invalid_trait_ids=$(invalid_trait_identifiers_in "$configuration_entries")
[ -z "$invalid_trait_ids" ] || { echo "$invalid_trait_ids"; exit 2; }

# Asserts trait-ID uniqueness.
readonly duplicate_trait_ids=$(duplicate_trait_identifiers_in "$configuration_entries")
[ -z "$duplicate_trait_ids" ] || { echo "$duplicate_trait_ids"; exit 3; }

# Asserts trait-value wellformedness.
readonly malformed_trait_values=$(malformed_trait_values_in "$configuration_entries")
[ -z "$malformed_trait_values" ] || { echo "$malformed_trait_values"; exit 4; }

exit 0
