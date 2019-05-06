#!/bin/bash

# This script prints a formatted list of the defined racks and their components.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1

readonly rack_index="$dot/../../../$(path_for_ rack-index)"

# Prints a header. If there are no catalogued racks, an early return occurs.
if [ -s "$rack_index" ]; then
   echo 'The rack catalogue contains the following racks:'
else
   echo 'The rack catalogue is empty.'
   exit 0
fi

# Iterates over the entries in the rack-index.
while read -r index_entry; do
   rack_name=$(data_for_ rack-name --in rack-index --entries "$index_entry")
   rack_directory=$(data_for_ rack-directory --in rack-index --entries "$index_entry")

   # Prints a header for the current rack.
   echo -e "\nRack '$print_yellow$rack_name$print_normal'"

   # Iterates over the current rack's manifest entries.
   while read -r manifest_entry; do
      instance_name=$(data_for_ instance-name --in rack-manifest --entries "$manifest_entry")
      server_name=$(data_for_ server-name --in rack-manifest --entries "$manifest_entry")

      echo "  • $instance_name: $server_name"
   done < "$rack_directory/$(name_for_ rack-manifest-file)"
done < "$rack_index"

exit 0
