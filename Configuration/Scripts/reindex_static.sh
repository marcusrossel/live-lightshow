#!/bin/bash

# This script generates a new static index and with a corresponding static configuration directory.
# Older, unused configuration files will remain in the static configuration directory, but will not
# affect anything.
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
. "$dot/../../Utilities/types.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly static_index="$dot/../../$(path_for_ static-index)"

   return 0
}


#-Functions-------------------------------------#


# Prints the static configuration corresponding to the trait declarations contained in a given file.
#
# A static configuration has the form:
# <trait 1 ID>:<trait 1 value>:<trait 1 type>
# <trait 2 ID>:<trait 2 value>:<trait 2 type>
# ...
#
# Arguments:
# * <program file>
#
# Return status:
# 0: success
# 1: internal error
function static_configuration_for_file_ {
   # Gets and iterates over the list of trait declarations in the given file.
   egrep "$(regex_for_ trait)" "$1" | while read trait_declaration; do
      # Extracts the parameters from the declaration.
      local trait_identifier=$(cut -d '"' -f 2 <<< "$trait_declaration")
      local trait_value=$(echo "$trait_declaration" | cut -d ':' -f 2 | trimmed)
      local trait_value_type
      if ! trait_value_type=$(type_for_value_ "$trait_value"); then
         # This should be unreachable.
         print_error_for_ --internal; return 1
      fi

      # Prints the entry for the current declaration.
      echo "$trait_identifier:$trait_value:$trait_value_type"
   done

   return 0
}

# Sets up the static configuration file folder as to reflect the current static index. This entails # generating new configuration files and overwriting old ones with the new information.
function setup_static_configuration_files {
   # Iterates over the static index' entries.
   while read index_entry; do
      file_path=$(column_for_ file-path --in-entries "$index_entry" --of static-index)
      config_file=$(column_for_ config-file --in-entries "$index_entry" --of static-index)

      # Creates a new configuration file containing the appropriate static configuration.
      static_configuration_for_file_ "$file_path" > "$config_file"
   done < "$static_index"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Writes a new static index.
"$dot/static_index.sh" >"$static_index"

# Updates the static configuration directory.
setup_static_configuration_files

exit 0
