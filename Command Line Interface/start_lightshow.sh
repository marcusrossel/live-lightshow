#!/bin/bash

# This script sets up the environment for and starts the lightshow-program.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the user chose to quit


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting, lookup and index utilities.
. "$dot/../Utilities/scripting.sh"
. "$dot/../Utilities/lookup.sh"
. "$dot/../Utilities/index.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly arduino_port=$("$dot/arduino_trait.sh" --port); [ $? -eq 3 ] && exit 1
   readonly program_folder="$dot/../$(path_for_ lightshow-directory)"
}


#-Functions-------------------------------------#


# Prints a list of the form:
# <class name 1>:<static configuration file 1>:<runtime configuration file 1>
# <class name 2>:<static configuration file 2>:<runtime configuration file 2>
# ...
# for each server instance in the runtime index.
#
# This map is used in the lightshow program to instantiate the server instances.
function server_instantiation_map {
   # Gets constants.
   local -r static_index="$dot/../$(path_for_ static-index)"
   local -r runtime_index="$dot/../$(path_for_ runtime-index)"
   local -r runtime_server_id_column=$(column_number_for_ server-id --in runtime-index)
   local -r runtime_config_file_column=$(column_number_for_ config-file --in runtime-index)

   # Iterates over the runtime-index.
   while read runtime_entry; do
      # Gets the server-ID associated with the current runtime entry's server instance.
      local server_id=$(cut -d : -f $runtime_server_id_column <<< "$runtime_entry")

      # Gets the components for a server instantiation map entry.
      local class_name=$(static_ class-name --for server-id "$server_id")
      local static_config_file=$(static_ config-file --for server-id "$server_id")
      local runtime_config_file=$(cut -d : -f $runtime_config_file_column <<< "$runtime_entry")

      # Prints the server instantiation map entry.
      echo "$class_name:$static_config_file:$runtime_config_file"
   done < "$runtime_index"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Sets up the runtime environment, or exits if the user chose to quit.
"$dot/../Configuration/Scripts/setup_runtime.sh" || exit 2

# Gets the server instantiation map (SIM).
readonly sim=$(server_instantiation_map)

# Starts the lightshow program, while passing it the Arduino's port and the SIM.
silently- processing-java --sketch="$program_folder" --run "$arduino_port" "$sim" &
