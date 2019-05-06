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
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"


#-Functions--------------------------------------#


# Sets up the runtime configuration file folder as to reflect the current runtime index. This
# entails generating new configuration files and overwriting old ones with the new information.
function setup_runtime_configuration_files {
   # Iterates over the runtime index' entries.
   while read runtime_entry; do
      # Gets the server-ID and configuration file of the runtime entry.
      server_id=$(data_for_ server-name --in runtime-index --entries "$runtime_entry")
      runtime_config_file=$(data_for_ config-file --in runtime-index --entries "$runtime_entry")

      # Gets the static configuration file corresponding to the runtime entry's server-ID.
      static_config_file=$(fields_for_ config-file --with server-name "$server_id" --in static-index)

      # Copies the contents of the static configuration file for current server-ID, to the current
      # runtime configuration file.
      cat "$static_config_file" >"$runtime_config_file"
   done < "$dot/../../../$(path_for_ runtime-index)"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1

# Writes a new runtime index.
readonly runtime_index="$dot/../../../$(path_for_ runtime-index)"
"$dot/write_runtime_index_into.sh" "$runtime_index" || exit 2

# Updates the runtime configuration directory.
setup_runtime_configuration_files

exit 0
