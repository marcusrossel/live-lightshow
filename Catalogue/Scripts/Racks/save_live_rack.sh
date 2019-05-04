#!/bin/bash

# This script captures the current setup of a running live show and saves it as a rack with a given
# name.
#
# Arguments:
# * <rack name>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the given name is already taken


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

# Makes sure the given rack name is not already in use.
if $(string_ "$rack_name" --is-line-in-string "$(data_for_ rack-name --in rack-index)"); then
   print_error_for "Script received taken rack name '$print_yellow$rack_name$print_normal'."
   exit 2
fi

# Gets the number after the largest taken directory name (number) in the rack-index.
new_id_number=0
while read -r rack_directory; do
   [ -n "$rack_directory" ] || break

   id_number=$(basename "$rack_directory")
   [ "$id_number" -ge "$new_id_number" ] && new_id_number=$((id_number + 1))
done <<< "$(data_for_ rack-directory --in rack-index)"

# Creates the path for the new rack's directory.
readonly rack_directory="$dot/../../../$(path_for_ rack-data-directory)/$new_id_number"
# Creates the directory for the new rack.
mkdir "$rack_directory"
# Adds a rack-index entry for the new rack.
echo "$rack_name:$(realpath "$rack_directory")" >> "$dot/../../../$(path_for_ rack-index)"

# Writes a slightly edited version of the runtime-index into the rack's manifest, while also
# copying necessary configuration files.

readonly rack_manifest="$rack_directory/$(name_for_ rack-manifest-file)"

# Iterates over the entries in the runtime-index.
while read -r entry; do
   instance_name=$(data_for_ instance-name --in runtime-index --entries "$entry")
   server_name=$(data_for_ server-name --in runtime-index --entries "$entry")
   config_file=$(data_for_ config-file --in runtime-index --entries "$entry")

   # Writes the manifest entry.
   echo "$instance_name:$server_name:$(basename "$config_file")" >> "$rack_manifest"

   # Copies the configuration file into the rack's directory.
   cp "$config_file" "$rack_directory"
done < "$dot/../../../$(path_for_ runtime-index)"

exit 0
