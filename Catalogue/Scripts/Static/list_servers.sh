#!/bin/bash

# This script prints a formatted list of the defined servers.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1

readonly static_index="$dot/../../../$(path_for_ static-index)"

# Prints a header. If there are no catalogued servers, an early return occurs.
if egrep -q -v '^\s*$' "$static_index"; then
    echo 'The server catalogue contains the following servers:'
else
    echo 'The server catalogue is empty.'
    exit 0
fi

# Iterates over the entries in the static-index.
while read -r index_entry; do
   server_name=$(data_for_ server-name --in static-index --entries "$index_entry")

   # Prints the current server.
   echo -e "  • '$print_yellow$server_name$print_normal'"
done < "$static_index"

exit 0
