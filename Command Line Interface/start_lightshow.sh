#!/bin/bash

# This script sets up the environment for and starts the lightshow-program.
#
# Arguments:
# <rack name> optional
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the user chose to quit
# 3: the given rack name was invalid


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot/../Utilities/scripting.sh"
. "$dot/../Utilities/lookup.sh"
. "$dot/../Utilities/data.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly rack_name=$1
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
      local server_id=$(data_for_ server-name --in runtime-index --entries "$runtime_entry")

      # Gets the components for a server instantiation map entry.
      local class_name=$(fields_for_ class-name --with server-name "$server_id" --in static-index)
      local static_config_file=$(
         fields_for_ config-file --with server-name "$server_id" --in static-index
      )
      local runtime_config_file=$(
         data_for_ config-file --in runtime-index --entries "$runtime_entry"
      )

      # Prints the server instantiation map entry.
      echo "$class_name:$static_config_file:$runtime_config_file"
   done < "$dot/../$(path_for_ runtime-index)"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 1 '<rack name: optional>' || exit 1
declare_constants "$@"

if [ -z "$rack_name" ]; then
   # Sets up the runtime environment, or exits if the user chose to quit.
   "$dot/../Catalogue/Scripts/Runtime/setup_runtime.sh" || exit 2
else
   # Loads the rack with the given name, or exits if that fails.
   silently- "$dot/../Catalogue/Scripts/Racks/load_rack.sh" "$rack_name" || exit 3
fi

echo -e "${print_green}Connecting to Arduino...$print_normal"

# Gets the Arduino's port.
readonly arduino_port=$("$dot/arduino_trait.sh" --port); [ $? -eq 3 ] && exit 1

echo -e "${print_green}Starting light show...$print_normal"

# Gets the server instantiation map (SIM).
readonly sim=$(server_instantiation_map)

# Copies all servers' program files to the lightshow program directory for compilation.
cp "$servers_directory"/* "$program_directory"

# Starts the lightshow program, while passing it the Arduino's port and the SIM.
processing-java --sketch="$program_directory" --run "$arduino_port" "$sim" &

# Waits for the lightshow to compile and then removes all servers' program files from the lightshow
# program directory.
# TODO: Remove the hardcoded value by doing this after compilation ends.
sleep 5
for server_file in $(ls "$servers_directory"); do
   rm "$program_directory/$(basename "$server_file")"
done

echo -e "${print_green}Light show running.$print_normal"

exit 0
