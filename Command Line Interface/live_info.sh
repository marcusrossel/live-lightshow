#!/bin/bash

# This script prints a description of the light show's currently specified server instances.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments

#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot/../Utilities/scripting.sh"
. "$dot/../Utilities/lookup.sh"
. "$dot/../Utilities/data.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1

echo -e "${print_green}A light show is currently running$print_normal with the following setup:"

# Iterates over the entries in the runtime index.
while read -r index_entry; do
   instance_id=$(data_for_ instance-name --in runtime-index --entries "$index_entry")
   server_id=$(data_for_ server-name --in runtime-index --entries "$index_entry")
   config_file=$(data_for_ config-file --in runtime-index --entries "$index_entry")

   # Prints a header for the current server instance.
   echo -e "\nInstance '$print_yellow$instance_id$print_normal' of server type" \
           "'$print_yellow$server_id$print_normal'"

   # Iterates over the current server instance's runtime configuration entries.
   while read -r config_entry; do
      trait_id=$(data_for_ trait-name --in runtime-config --entries "$config_entry")
      trait_value=$(data_for_ trait-value --in runtime-config --entries "$config_entry")

      echo "  • $trait_id: $trait_value"
   done < "$config_file"
done < "$dot/../$(path_for_ runtime-index)"

exit 0
