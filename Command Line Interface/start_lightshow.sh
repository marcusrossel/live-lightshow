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
   readonly program_directory="$dot/../$(path_for_ lightshow-directory)"
   readonly servers_directory="$dot/../$(path_for_ servers-directory)"
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
   # Iterates over the runtime-index.
   while read runtime_entry; do
      # Gets the server-ID associated with the current runtime entry's server instance.
      local server_id=$(column_for_ server-id --in-entries "$runtime_entry" --of runtime-index)

      # Gets the components for a server instantiation map entry.
      local class_name=$(values_for_ class-name --in static-index --with server-id "$server_id")
      local static_config_file=$(values_for_ config-file --in static-index \
                                                       --with server-id "$server_id")
      local runtime_config_file=$(column_for_ config-file --in-entries "$runtime_entry" \
                                                                  --of runtime-index)

      # Prints the server instantiation map entry.
      echo "$class_name:$static_config_file:$runtime_config_file"
   done < "$dot/../$(path_for_ runtime-index)"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Sets up the runtime environment, or exits if the user chose to quit.
"$dot/../Configuration/Scripts/setup_runtime.sh" || exit 2

# Gets the server instantiation map (SIM).
readonly sim=$(server_instantiation_map)

# Copies all servers' program files to the lightshow program directory for compilation.
# TODO: Make sure none of the servers are called "Server", "Configuration", or "Lightshow".
cp "$servers_directory"/* "$program_directory"

# Starts the lightshow program, while passing it the Arduino's port and the SIM.
processing-java --sketch="$program_directory" --run "$arduino_port" "$sim" &

# Removes all servers' program files from the lightshow program directory after compilation.
for server_file in $(ls "$servers_directory"); do
   # TODO: Change this to `rm` when safe.
   rem "$program_directory/$(basename "$server_file")"
done
