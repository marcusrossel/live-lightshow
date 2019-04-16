#!/bin/bash

# This script installs all of the components needed for the Live Lightshow to run. Dependencies are
# described by <lookup file: dependency urls>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: downloading dependencies failed
# 3: post-install tests failed

#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports lookup and CLI utilities.
. "$_dot/../Lookup Files/lookup.sh"
. "$_dot/../Command Line Interface/Scripts/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly downloads_directory='downloads'

   return 0
}


#-Functions-------------------------------------#


function install_dependencies_ {
   # Moves the StandardFirmata program directory into the "Program" directory.
   local -r firmata_folder=$(basename "$(path_for_ standard-firmata-directory)")
   mv "$dot/$downloads_directory/$firmata_folder" "$dot/../Program"

   # Moves the Arduino-CLI to a $PATH-directory.
   local -r arduino_cli=$(name_for_ arduino-cli)
   sudo mv "$dot/$downloads_directory/$arduino_cli" "$(path_for_ arduino-cli-destination)"

   # Installs the Arduino UNO core.
   local -r uno_fqbn=$(name_for_ arduino-uno-fbqn)
   # Installs the Arduino-UNO board core.
   silently- arduino-cli core install "$uno_fqbn"

   # Installs Processing by moving it to the top-level repository directory.
   local -r processing=$(name_for_ processing)
   mv "$dot/$downloads_directory/$processing" "$dot/.."

   # Installs the libraries, by moving them to the sketchbook>libraries directory.
   local -r libraries_directory="$(get_sketchbook_path_)/$(name_for_ processing-lib-directory)"
   local -r arduino_processing_lib=$(name_for_ arduino-processing-lib)
   local -r ddfs_minim_lib=$(name_for_ ddfs-minim-lib)
   mv "$dot/$downloads_directory/$arduino_processing_lib" "$libraries_directory"
   mv "$dot/$downloads_directory/$ddfs_minim_lib" "$libraries_directory"
}

# This script get's Processing's Sketchbook-path by prompting the user to provide it. The result is
# printed to stdout.
#
# Return status:
# 0: success
# 1: the user chose to quit
function get_sketchbook_path_ {
   # TODO: Implement.
}

# Writes the location of the application directory into the CLI command's script.
#
# Return status:
# 0: success
# 1: the CLI command's script does not contain the required tag
# 2: the CLI command's script contains a malformed application directory declaration
function tag_cli_command_ {
   # Gets the path to the CLI command.
   local -r command_script="$dot/../$(path_for_ cli-command-source)"
   # Gets the regular expression used to search for the application directory tag.
   local -r tag_pattern=$(regex_for_ app-directory-tag)
   # Gets the line in the CLI command containing the tag.
   local -r tag_line=$(egrep -n "$tag_pattern" "$command_script")

   # Makes sure that a line with the tag was found, or prints an error and returns on failure.
   if [ -z "$tag_line" ]; then
      echo "Error: \`$command_script\` does not contain the required application directory tag" >&2
      return 1
   fi

   # Gets the line number of the folder declaration itself.
   local -r folder_line_number=$[$(cut -d : -f 1 <<< "$tag_line") + 1]
   # Gets the path of the application directory.
   local -r app_directory=$(path_for_ app-directory)

   # Constructs a string containing the line, with everything after the equals-sign replaced by the
   # relevant path.

   local -r folder_declaration_line=$(sed -n "${folder_line_number}p" "$command_script")
   local -r folder_declaration_prefix=$(egrep -o '.*=' <<< "$folder_declaration_line")

   # Makes sure the folder declaration was wellformed, or prints an error and returns on failure.
   if [ -z "$folder_declaration_prefix" ]; then
      echo "Error: \`$command_script\` contains a malformed application directory declaration" >&2
      return 2
   fi

   local -r completed_declaration="$folder_declaration_prefix'$app_directory'"

   # Removes the previous folder declaration from the command's script.
   sed -i -e "${folder_line_number}d" "$command_script"
   # Replaces the previous folder declaration in the command's script with the completed one.
   ex -s -c "${folder_line_number}i|$completed_declaration" -c 'x' "$command_script"

   return 0
}

# Installs the Live Lightshow application by copying the repository (minus redundant files) to the
# application directory, and moving the CLI-command to its destination.
function install_application {
   # Removes all of the redundant items from the repository.
   local downloads_suffix=$'\n'$downloads_directory
   local -r redundant_items=$(path_for_ delete-with-install)$downloads_suffix
   while read item; do rm -r "$dot/../$item"; done <<< "$redundant_items"

   # Moves the CLI-command to its destination.
   sudo mv "$dot/../$(path_for_ cli-command-source)" "$(path_for_ cli-command-destination)"

   # Moves the repository to its destination.
   mv "$dot/.." "$(path_for_ app-directory)"

   return 0
}

# This script prompts the user to install processing's command line tool (processing-java), if they
# are on macOS.
# This should only happen, once Processing has been moved to its final destination.
#
# Return status:
# 0: success
# 1: the user chose to quit
function prompt_for_macOS_tools_ {
   # TODO: Implement.
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Creates the downloads' directory, and makes sure it is removed when exiting.
mkdir "$dot/$downloads_directory"
trap "rm -r '$dot/$downloads_directory'" EXIT

# Tries to download the dependencies, or else returns on failure.
"$dot/download_dependencies.sh" "$downloads_directory" || exit 2

install_dependencies_ || # ...
tag_cli_command_ || # ...
install_application

if [ "$OSTYPE" ~= darwin* ]; then
   prompt_for_macOS_tools_ || # ...
fi

exit 0
