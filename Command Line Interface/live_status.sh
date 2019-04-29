#!/bin/bash

# This script prints a description of the light show's currently spcified server instances.


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports scripting, lookup and index utilities.
. "$dot/../Utilities/scripting.sh"
. "$dot/../Utilities/lookup.sh"
. "$dot/../Utilities/index.sh"


#-Main------------------------------------------#


# Prints a description of all of the server instances in the currently running light show.
echo -e "${print_green}A light show is currently running$print_normal with the following setup:"

# Iterates over the entries in the runtime index.
while read -r index_entry; do
   instance_id=$(column_for_ instance-id --in-entries "$index_entry" --of runtime-index)
   server_id=$(column_for_ server-id --in-entries "$index_entry" --of runtime-index)
   config_file=$(column_for_ config-file --in-entries "$index_entry" --of runtime-index)

   # Prints a header for the current server instance.
   echo
   echo -e "Instance '$print_yellow$instance_id$print_normal' of server type" \
           "'$print_yellow$server_id$print_normal'"

   # Iterates over the current server instance's runtime configuration entries.
   while read -r config_entry; do
      trait_id=$(cut -d : -f 1 <<< "$config_entry")
      trait_value=$(cut -d : -f 2 <<< "$config_entry")

      echo "  ◦ $trait_id: $trait_value"
   done < "$config_file"
done < "$dot/../$(path_for_ runtime-index)"

exit 0
