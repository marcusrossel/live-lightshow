#!/bin/bash

# This script installs all of the components needed for the Live Lightshow to run. Dependencies are
# described by <lookup file: dependency urls>.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: downloading dependencies failed
# 3: the user chose to quit
# 4: repository-interal error
# 5: post-install tests failed


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot/../Utilities/scripting.sh"
. "$dot/../Utilities/lookup.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly relative_downloads_directory=$(path_for_ downloads-directory)
   readonly app_directory=$(path_for_ app-directory)

   return 0
}


#-Functions-------------------------------------#


# Moves all of the dependencies (expected to be in the $relative_downloads_directory) to their
# intended destinations, etc.
#
# Return status:
# 0: success
# 1: the user chose to quit
function install_dependencies_ {
   # Moves the StandardFirmata program directory into the "Program" directory.
   local -r firmata_folder=$(basename "$(path_for_ firmata-directory)")
   mv "$dot/../$relative_downloads_directory/$firmata_folder" "$dot/../Program"

   # Moves the Arduino-CLI to a $PATH-directory.
   local -r arduino_cli=$(name_for_ arduino-cli)
   echo -e "${print_green}The installer requires your password: $print_normal" >&2
   sudo mv "$dot/../$relative_downloads_directory/$arduino_cli" \
           "$(path_for_ arduino-cli-destination)"

   # Installs the Arduino UNO core.
   local -r uno_core_name=$(name_for_ arduino-uno-core)
   arduino-cli core update-index
   arduino-cli core install "$uno_core_name"

   # Installs the Servo and Firmata libraries using the Arduino CLI.
   arduino-cli lib update-index
   arduino-cli lib install Servo
   arduino-cli lib install Firmata

   # Installs Processing by moving it to the top-level repository directory.
   local -r processing=$(name_for_ processing)
   mv "$dot/../$relative_downloads_directory/$processing" "$dot/.."

   # Installs the libraries, by moving them to the sketchbook>libraries directory.
   local sketchbook_path
   sketchbook_path=$(get_sketchbook_path_ "$dot/../$processing")  || return $?
   local -r libraries_directory="$sketchbook_path/$(name_for_ processing-lib-directory)"
   local -r arduino_processing_lib=$(name_for_ arduino-processing-lib)
   local -r ddfs_minim_lib=$(name_for_ ddfs-minim-lib)
   silently- mv "$dot/../$relative_downloads_directory/$arduino_processing_lib" \
                "$libraries_directory"
   silently- mv "$dot/../$relative_downloads_directory/$ddfs_minim_lib" "$libraries_directory"

   return 0
}

# Get's Processing's Sketchbook-path by prompting the user to provide it. The result is printed to
# stdout.
#
# Arguments:
# * <processing app path>
#
# Return status:
# 0: success
# 1: the user chose to quit
function get_sketchbook_path_ {
   echo -e "\n${print_yellow}Please provide Processing's Sketchbook directory." >&2
   echo -e "You can find it by opening Processing and navigating to the preferences.$print_normal" >&2

   # Makes sure the user wants to continue, or returns on failure.
   echo -e "${print_green}Do you want to continue? [y or n]$print_normal" >&2
   succeed_on_approval_ || return 1

   # Opens Processing on macOS, or displays where to find the app on other OSs.
   if [ "$(current_OS_)" = 'macOS' ]; then
      silently- "$1/$(name_for_ processing-executable)" &
      sleep 3 # TODO: Hacky.
      processing_PID=$!;
   else
      echo -e "You can find the Processing application at $print_yellow$1$print_normal" >&2
   fi

   # Gets and prints out the sketchbook path.
   echo -e "${print_green}Paste the path here and hit [ENTER]: $print_normal" >&2
   read; echo "$REPLY"

   # Closes processing if it was opened by this script.
   [ -n "$processing_PID" ] && silently- kill "$processing_PID"

   return 0
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
      print_error_for "'$print_yellow$command_script$print_normal' does not contain the required" \
                      "application directory tag."
      return 1
   fi

   # Gets the line number of the folder declaration itself.
   local -r tag_line_number=$(cut -d : -f 1 <<< "$tag_line")
   local -r folder_line_number=$((tag_line_number + 1))

   # Constructs a string containing the line, with everything after the equals-sign replaced by the
   # relevant path.

   local -r folder_declaration_line=$(sed -n "${folder_line_number}p" "$command_script")
   local -r folder_declaration_prefix=$(egrep -o '.*=' <<< "$folder_declaration_line")

   # Makes sure the folder declaration was wellformed, or prints an error and returns on failure.
   if [ -z "$folder_declaration_prefix" ]; then
      print_error_for "'$print_yellow$command_script$print_normal' contains a malformed" \
                      "application directory declaration."
      return 2
   fi

   local -r completed_declaration="$folder_declaration_prefix'$app_directory'"

   # Removes the previous folder declaration from the command's script.
   sed -i '' -e "${folder_line_number}d" "$command_script"
   # Replaces the previous folder declaration in the command's script with the completed one.
   ex -s -c "${folder_line_number}i|$completed_declaration" -c 'x' "$command_script"

   return 0
}

# Installs the Live Lightshow application by copying the repository (minus redundant files) to the
# application directory, and moving the CLI-command to its destination.
function install_application {
   # Removes the downloads directory from the repository.
   silently- rm -r "$dot/../$relative_downloads_directory"

   # Moves the CLI-command to its destination.
   sudo mv "$dot/../$(path_for_ cli-command-source)" "$(path_for_ cli-command-destination)"

   # Copies this repository to its destination and updates its owner to be the user again.
   sudo cp -R "$dot/.." "$app_directory"
   sudo chown -R $USER: "$app_directory"

   return 0
}

# This script prompts the user to install processing's command line tool (processing-java), if they
# are on macOS.
#
# Return status:
# 0: success
# 1: the user chose to quit
function prompt_for_macOS_tools_ {
   echo -e "\n${print_yellow}Please install processing-java, from Processing's 'Tools' menu.$print_normal" >&2

   # Makes sure the user wants to continue, or returns on failure.
   echo -e "${print_green}Do you want to continue? [y or n]$print_normal"  >&2
   succeed_on_approval_ || return 1

   # Opens the instance of Processing that's in the application directory and
   # waits for the user to continue.
   "$(name_for_ processing)/$(name_for_ processing-executable)" &
   sleep 3 # TODO: Hacky.
   echo -e "${print_green}Press any button once processing-java is installed.$print_normal" >&2
   read -n 1

   # Closes Processing, if it was only open because of this installer.
   silently- kill $processing_PID

   return 0
}

# Updates the processing-java script to refer to the new location of the Processing executable.
# This should be done after Processing has been moved to its final location.
function update_processing_java {
   local -r processing_app=$(name_for_ processing)
   local -r processing_java=$(path_for_ 'processing-java')

   # Gets the path of the Processing app, as currently referred to in the
   # processing-java script.
   local -r previous_full_path=$(
      egrep '^cd' "$processing_java" | cut -d '"' -f 2
   )
   local -r partial_previous_path=${previous_full_path%%/$processing_app*}
   local -r previous_path=$partial_previous_path/$processing_app
   local -r sed_safe_previous=$(sed_safe_ -s "\"$previous_path")

   local -r escaped_previous_path=$(sed -e 's/ /\\ /g' <<< "$previous_path")
   local -r sed_safe_escaped_previous=$(sed_safe_ -s "$escaped_previous_path")

   # Gets the actual final path of the Processing app.
   local -r new_path="$app_directory/$processing_app"
   local -r sed_safe_new=$(sed_safe_ -r "\"$new_path")

   local -r escaped_new_path=$(sed -e 's/ /\\ /g' <<< "$new_path")
   local -r sed_safe_escaped_new=$(sed_safe_ -r "$escaped_new_path")

   # Replaces all occurrences of the previous path with the new path.
   sed -i '' -e "s/$sed_safe_previous/$sed_safe_new/" "$processing_java"
   sed -i '' -e "s/$sed_safe_escaped_previous/$sed_safe_escaped_new/" "$processing_java"
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Tries to download the dependencies, or else returns on failure.
echo 'Downloading dependencies:' >&2
"$dot/download_dependencies.sh" "$dot/../$relative_downloads_directory" || exit 2

install_dependencies_ || exit 3
tag_cli_command_ || exit 4
install_application

# Moves to the application directory as specified by <lookup file: file paths>.
cd "$app_directory"

# Prompts the user to install the processing-java utility, as this has to be done seperately on
# macOS.
if [ "$(current_OS_)" = 'macOS' ]; then
   prompt_for_macOS_tools_ || exit 3
fi

# Updates the processing-java script to refer to the new location of the Processing executable.
# This should done after Processing has been moved to its final location.
update_processing_java

# TODO: Check if the commands are working, make sure the sketchbook path is valid and the tests pass.

exit 0
