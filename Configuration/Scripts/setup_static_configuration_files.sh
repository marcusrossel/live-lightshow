#!/bin/bash

# This script sets up the static configuration file folder as to reflect the current static index.
# This entails generating new configuration files and overwriting old ones with the new information.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments


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
   readonly lightshow_program_directory="$dot/../../$(path_for_ lightshow-directory)"
   readonly static_configuration_directory="$dot/../../$(path_for_ static-configuration-directory)"

   readonly static_index="$dot/../../$(path_for_ static-index)"
   readonly config_file_column=$(column_number_for_ config-file --in static-index)
   readonly file_path_column=$(column_number_for_ file-path --in static-index)

   return 0
}


#-Functions-------------------------------------#


# Prints the trait configuration corresponding to the trait declarations contained in a given file.
#
# A trait configuration has the form (note the space after the colon):
# <trait 1 ID>: <trait 1 value>
# <trait 2 ID>: <trait 2 value>
# ...
#
# Arguments:
# * <program file>
function trait_configuration_for_file {
   # Gets the trait declarations in the file.
   local -r trait_pattern=$(regex_for_ trait)
   local -r trait_declarations=$(egrep "$trait_pattern" "$1")

   # Exctracts the parameters from the declaration.
   local -r trait_identifiers=$(cut -d '"' -f 2 <<< "$trait_declarations")
   local -r trait_values=$(cut -d ':' -f 2 <<< "$trait_declarations")

   # Prints the result and returns succesfully.
   paste -d ':' <(echo "$trait_identifiers") <(echo "$trait_values")
   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Iterates over the static index' entries.
while read index_entry; do
   file_path=$(cut -d : -f "$file_path_column" <<< "$index_entry")
   config_file=$(cut -d : -f "$config_file_column" <<< "$index_entry")

   # Creates a new configuration file containing the appropriate trait configuration.
   trait_configuration_for_file "$file_path" > "$config_file"
done < "$static_index"

exit 0
