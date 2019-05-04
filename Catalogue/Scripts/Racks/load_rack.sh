#!/bin/bash

# This script writes the rack with a given name into the current runtime data catalogue.
#
# Arguments:
# * <rack name>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the given rack name is undefined


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/catalogue.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 1 '<rack name>' || exit 1
readonly rack_name=$(trimmed $1)

# Makes sure the given rack name is defined.
if ! $(string_ "$rack_name" --is-line-in-string "$(data_for_ rack-name --in rack-index)"); then
   print_error_for "Script received undefined rack name '$print_yellow$rack_name$print_normal'."
   exit 2
fi

# Gets the directory for the given rack name.
readonly rack_directory=$(fields_for_ rack-directory --with rack-name "$rack_name" --in rack-index)

# Empties the runtime-index.
readonly runtime_index="$dot/../../../$(path_for_ runtime-index)"
echo -n > "$runtime_index"

# Writes a slightly edited version of the rack's manifest into the runtime-index, while also
# (over-)writing the necessary configuration files.

readonly runtime_data_directory="$dot/../../../$(path_for_ runtime-data-directory)"

# Iterates over the entries in the rack's manifest.
while read -r entry; do
   instance_name=$(data_for_ instance-name --in rack-manifest --entries "$entry")
   server_name=$(data_for_ server-name --in rack-manifest --entries "$entry")
   config_file=$(data_for_ config-file --in rack-manifest --entries "$entry")

   # Generates the path of the config file in the runtime data catalogue.
   runtime_config_file="$(realpath "$runtime_data_directory/$config_file")"

   # Writes the runtime-index entry.
   echo "$instance_name:$server_name:$runtime_config_file" >> "$runtime_index"

   # (Over-)writes the configuration file in the runtime data catalogue.
   cat "$rack_directory/$config_file" > "$runtime_config_file"
done < "$rack_directory/$(name_for_ rack-manifest-file)"

exit 0
