#!/bin/bash

# This script sets up the runtime configuration file folder as to reflect the current runtime index.
# This entails generating new configuration files and overwriting old ones with the new information.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: internal error


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
   readonly runtime_index="$dot/../../$(path_for_ runtime-index)"
   readonly static_index="$dot/../../$(path_for_ static-index)"

   readonly runtime_server_id_column=$(column_number_for_ server-id --in runtime-index)
   readonly runtime_config_file_column=$(column_number_for_ config-file --in runtime-index)

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Iterates over the runtime index' entries.
while read runtime_entry; do
   # Gets the server-ID and configuration file of the runtime entry.
   server_id=$(cut -d : -f $runtime_server_id_column <<< "$runtime_entry")
   runtime_config_file=$(cut -d : -f $runtime_config_file_column <<< "$runtime_entry")

   # Gets the static configuration file corresponding to the runtime entry's server-ID.
   static_config_file=$(static_ config-file --for server-id "$server_id")

   # Aborts if the previous operation didn't work.
   [ $? -ne 0 ] && { echo "Internal error: \`${BASH_SOURCE[0]}\`"; exit 2; }

   # Copies the contents of the static configuration file for current server-ID, to the current
   # runtime configuration file.
   cat "$static_config_file" >"$runtime_config_file"
done < "$runtime_index"

exit 0
