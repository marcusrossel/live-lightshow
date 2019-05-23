#!/bin/bash

# This script prints a description of the rack with given name.
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
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 1 '<rack name>' || exit 1
readonly rack_name=$1

# Gets the directory of the rack with the given name, and exits if it is not defined.
readonly rack_directory=$(fields_for_ rack-directory --with rack-name "$rack_name" --in rack-index)
if [ -z "$rack_directory" ]; then
   print_error_for "Script received undefined rack name '$print_yellow$rack_name$print_normal'."
   exit 2
fi

echo -e "The rack '$print_green$rack_name$print_normal' has the following setup:"

# Iterates over the entries in the rack's manifest.
while read -r manifest_entry; do
   instance_id=$(data_for_ instance-name --in rack-manifest --entries "$manifest_entry")
   server_id=$(data_for_ server-name --in rack-manifest --entries "$manifest_entry")
   config_file=$(data_for_ config-file --in rack-manifest --entries "$manifest_entry")

   # Gets the rack-relative config-file path for the current server instance.
   rack_config_file="$rack_directory/$config_file"

   # Prints a header for the current server instance.
   echo -e "\nInstance '$print_yellow$instance_id$print_normal' of server type" \
           "'$print_yellow$server_id$print_normal'"

   # Iterates over the current server instance's rack configuration entries.
   while read -r config_entry; do
      trait_name=$(data_for_ trait-name --in runtime-config --entries "$config_entry")
      trait_value=$(data_for_ trait-value --in runtime-config --entries "$config_entry")

      echo "  • $trait_name: $trait_value"
   done < "$rack_config_file"
done < "$rack_directory/$(name_for_ rack-manifest-file)"

exit 0
