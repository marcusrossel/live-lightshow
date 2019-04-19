#!/bin/bash

# This script gets the user configuration from the user, creates the runtime index, and sets up the
# runtime configuration files.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the user chose to quit


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting, lookup and index utilities.
. "$dot/../../Utilities/scripting.sh"
. "$dot/../../Utilities/lookup.sh"
. "$dot/../../Utilities/index.sh"


#-Functions--------------------------------------#


# Sets up the runtime configuration file folder as to reflect the current runtime index. This
# entails generating new configuration files and overwriting old ones with the new information.
function setup_runtime_configuration_files {
   # Iterates over the runtime index' entries.
   while read runtime_entry; do
      # Gets the server-ID and configuration file of the runtime entry.
      server_id=$(column_for_ server-id --in-entries "$runtime_entry" --of runtime-index)
      runtime_config_file=$(column_for_ config-file --in-entries "$runtime_entry" \
                                                            --of runtime-index)

      # Gets the static configuration file corresponding to the runtime entry's server-ID.
      static_config_file=$(values_for_ config-file --in static-index --with server-id "$server_id")

      # Copies the contents of the static configuration file for current server-ID, to the current
      # runtime configuration file.
      cat "$static_config_file" >"$runtime_config_file"
   done < "$dot/../../$(path_for_ runtime-index)"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1

# Writes a new runtime index.
readonly runtime_index="$dot/../../$(path_for_ runtime-index)"
"$dot/write_runtime_index_into.sh" "$runtime_index" || exit 2

# Updates the runtime configuration directory.
setup_runtime_configuration_files

exit 0
