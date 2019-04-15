#!/bin/bash

# This script installs all of the components needed for the Arduino Light Show CLI to run.
# This includes:
# * the Arduino-CLI (if not preinstalled)
# * an Arduino Light Show CLI script in some "$PATH"-directory
# * supporting files for the Arduino Light Show CLI script
# The exact directories and names of all of these files are specified by <utility file:
# file locations>.
# A connection to the internet is required as this script may download files.
#
# For the purpose of bootstrapping the installation process, this script expects certain
# preconditions pertaining to certain files' locations. These can be gathered from the constant
# declarations below.
#
# Return status:
# 0: success
# 1: download of the repository failed
# 2: the user does not want to reinstall
# 3: the CLI-script has a malformed or no "CLI supporing files folder"-declaration
# 4: the installation of the Arduino-CLI failed

# TODO: Add a different "supporting files" destination for (Windows Subsystem for) Linux.


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   # A hardcoded URL to the Arduino Light Show repository.
   readonly repository_url='https://github.com/WalkingPizza/arduino-light-show/archive/master.zip'
   # A hardcoded path to the CLI-utilities, needed for bootstrapping the installation.
   readonly cli_utilities='Command Line Interface/Libraries/utilities.sh'
   # A hardcoded path to the CLI-constants, needed for bootstrapping the installation.
   readonly cli_constants='Command Line Interface/Libraries/constants.sh'
   # The name of the folder as which the repository above will be unarchived.
   readonly repository_folder='arduino-light-show-master'
   # A unique temporary working directory used as sandbox for the installation process.
   readonly working_directory=`mktemp -d`

   return 0
}


#-Functions-------------------------------------#


# Sets up a certain environment for the further steps in the installation process.
# After running this function the current working directory is "$working_directory", which contains
# a folder "$repository_folder" which contains all of the contents ot the Arduino Light Show
# repository.
#
# Return status:
# 0: success
# 1: download of the repository failed
function setup_installation_environment_ {
   # Moves into the installation process' "sandbox".
   cd "$working_directory"

   echo 'Downloading Arduino Light Show CLI:'

   # Tries to download the repository into the "$repository_folder.zip" archive. If that is not
   # possible an error is printed and a return on failure occurs.
   if ! curl -Lk --progress-bar -o "$repository_folder.zip" "$repository_url"; then
      echo "Error: failed to download repository at \"$repository_url\"" >&2
      return 1
   fi

   echo 'Unpacking Arduino Light Show CLI...'

   # Unzips the archive into the "$repository_folder" and removes the archive.
   unzip "$repository_folder.zip" &>/dev/null
   rm "$repository_folder.zip"

   return 0
}

# Sets up the folder for the CLI's supporting files, so it exists and is empty. If one already
# exists, the user is prompted to choose whether to reinstall.
#
# Return status:
# 0: success
# 1: the user does not want to reinstall
function setup_cli_supporting_files_folder_ {
   # Gets the path of the folder in which the CLI's supporting files are supposed to be placed.
   local -r cli_supporing_files_destination=`location_of_ --cli-supporting-files-destination`

   # Creates the folder for the CLI's supporting files if none exists. If one already exists, the
   # user is prompted to choose whether they want to empty it and reinstall. If the user chooses not
   # to reinstall a return on failure occurs.
   if [ -d "$cli_supporing_files_destination" ]; then
      # Prompts the user and asks them for their decision.
      echo 'It seems you have run this installation before.' >&2
      echo -e '\033[0;32mDo you want to reinstall? [y or n]\033[0m' >&2
      succeed_on_approval_ || return 1

      # This is only executed if the user chose to reinstall.
      # Removes the existing CLI's supporting files folder.
      rm -r "$cli_supporing_files_destination/"
   fi

   # Creates the CLI's supporting files folder.
   mkdir -p "$cli_supporing_files_destination"

   return 0
}

# Installs the Ardunio-CLI as specified by <utility file: file locations>.
#
# Return status:
# 0: success
# 1: download of the Arduino-CLI failed
# 2: the downloaded file has an unexpected format
# 3: the installation of the Arduino-CLI failed
function install_arduino_cli_ {
   # Declares local constants.
   local -r archive='arduino_cli.zip'
   local -r unzipped_folder='arduino_cli'

   echo 'Downloading Arduino CLI:'

   # Tries to download the Ardunio-CLI archive into the "$archive" folder. If that doesn't work an
   # error is printed and a return on failure occurs.
   if ! curl --progress-bar -o $archive "`location_of_ --arduino-cli-source`"; then
      echo 'Error: failed to download Arduino CLI' >&2
      return 1
   fi

   echo 'Installing Arduino CLI...'

   # Unzips the archive into the "$unzipped_folder" and removes the archive.
   silently- unzip $archive -d $unzipped_folder
   rm $archive

   # Checks if the archive contains exactly one file (expected to be the Arduino-CLI script). If it
   # doesn't an error is printed and a return on failure occurs.
   local -r unzipped_files=`ls -1 $unzipped_folder`
   if ! [ `wc -l <<< "$unzipped_files"` -eq 1 ]; then
      echo 'Error: Arduino CLI installer changed' >&2
      return 2
   fi

   # Moves all files in the "$unzipped_folder" (so only the Arduino-CLI script) to its final
   # destination and renames it as specified by <utility file: file locations>. Any temporary
   # folders are removed as well.
   local -r arduino_cli_destination=`location_of_ --arduino-cli-destination`
   mv $unzipped_folder/* "$arduino_cli_destination"
   rm -r $unzipped_folder

   # Makes sure that the Ardunio-CLI is now properly installed. If not an error is printed and a
   # return on failure occurs.
   if ! silently- command -v "`basename "$arduino_cli_destination"`"; then
      echo 'Error: Arduino CLI installation failed' >&2
      return 3
   fi

   echo 'Installing Arduino Core...'

   # Gets the FQBN of the Arduino UNO.
   local -r uno_fqbn=`name_of_ --arduino-uno-fbqn`
   # Installs the Arduino-UNO board core.
   silently- arduino-cli core install "$uno_fqbn"

   echo 'Installed Arduino CLI.'
   return 0
}

# Writes the location of the CLI's supporting files folder into the CLI-script.
#
# Return status:
# 0: success
# 1: the CLI-script does not contain the required tag
# 2: the CLI-script contains a malformed CLI supporting files folder declaration
function complete_cli_script_ {
   # Gets the path of the CLI-script, relative to the repository as specified by <utility file:
   # file locations>.
   local -r repo_path="`location_of_ --repo-cli-directory`/`name_of_ --cli-command`"
   # Gets the path to the CLI-script as specified by <utility file: file locations>.
   local -r cli_script="$repository_folder/$repo_path"
   # Gets the regular expression used to search for the "CLI supporting files folder"-tag as
   # specified by <utility file: regular expressions>.
   local -r tag_pattern=`regex_for_ --cli-supporting-files-folder-tag`
   # Gets the line in the CLI-script containing the "CLI supporting files folder"-tag.
   local -r tag_line=`egrep -n "$tag_pattern" "$cli_script"`

   # Makes sure that a line with the folder-tag was found, or prints an error and returns on
   # failure.
   if [ -z "$tag_line" ]; then
      echo "Error: \`$cli_script\` does not contain a folder declaration tag" >&2
      return 1
   fi

   # Gets the line number of the folder declaration itself.
   local -r folder_line_number=$[`cut -d : -f 1 <<< "$tag_line"` + 1]

   # Gets the folder in which the CLI's supporting files are supposed to be installed as specified
   # by <utility file: file locations>.
   local -r cli_supporing_files_destination=`location_of_ --cli-supporting-files-destination`

   # Constructs a string containing the line, with everything after the equals-sign replaced by the
   # relevant path.

   local -r folder_declaration_line=`sed -n "${folder_line_number}p" "$cli_script"`
   local -r folder_declaration_prefix=`egrep -o '.*=' <<< "$folder_declaration_line"`

   # Makes sure the folder declaration was wellformed, or prints an error and returns on failure.
   if [ -z "$folder_declaration_prefix" ]; then
      echo "Error: \`$cli_script\` contains a malformed folder declaration" >&2
      return 2
   fi

   local -r completed_declaration="$folder_declaration_prefix'$cli_supporing_files_destination'"

   # Removes the previous folder declaration from the CLI-script.
   sed -i -e "${folder_line_number}d" "$cli_script"
   # Replaces the previous folder declaration in the CLI-script with the completed one.
   ex -s -c "${folder_line_number}i|$completed_declaration" -c 'x' "$cli_script"

   return 0
}

# Sets a flag in the uninstaller-script, indicating the Arduino-CLI should also be removed when
# uninstalling the Arduino Light Show CLI.
#
# Return status:
# 0: success
# 1: the uninstaller does not contain the required tag
function set_uninstall_ardunio_cli_flag_ {
   # Gets the path of the uninstaller-script, relative to the repository as specified by
   # <utility file: file locations>.
   local -r repo_path="`location_of_ --repo-cli-directory`/`location_of_ --cli-uninstaller`"
   # Gets the path to the uninstaller-script as specified by <utility file: file locations>.
   local -r uninstaller_script="$repository_folder/$repo_path"
   # Gets the regular expression used to search for the "uninstall Arduino CLI flag"-tag as
   # specified by <utility file: regular expressions>.
   local -r tag_pattern=`regex_for_ --uninstall-arduino-cli-flag-tag`
   # Gets the line in the uninstaller-script containing the "uninstall Arduino CLI flag"-tag.
   local -r tag_line=`egrep -n "$tag_pattern" "$uninstaller_script"`

   # Makes sure that a line with the flag-tag was found, or prints a warning and returns on failure.
   if [ -z "$tag_line" ]; then
      echo "Warning: \`$uninstaller_script\` does not contain a flag tag" >&2
      return 1
   fi

   # Gets the line number of the flag itself.
   local -r flag_line_number=$[`cut -d : -f 1 <<< "$tag_line"` + 1]

   # Replaces "=false" with "=true" in the uninstaller-script's flag line.
   sed -i '' -e "$flag_line_number s/=false/=true/" "$uninstaller_script"

   return 0
}

# Installs the Ardunio Light Show CLI by copying the CLI script as well as the CLI's supporting
# files to their destinations as specified by <utility file: file locations>.
function install_lightshow_cli {
   # Gets the folder in which the CLI's supporting files are supposed to be installed.
   local -r cli_supporing_files_destination=`location_of_ --cli-supporting-files-destination`
   # Gets the repository-internal relative path to the repository's CLI-folder.
   local -r repository_cli_directory=`location_of_ --repo-cli-directory`

   echo 'Installing Arduino Light Show CLI...'

   # Moves all of the directories that need to be moved to the CLI's supporting files folder.
   while read directory; do mv "$directory" "$cli_supporing_files_destination"; done << END
$repository_folder/$repository_cli_directory/$(location_of_ --cli-scripts-directory)
$repository_folder/$repository_cli_directory/$(location_of_ --cli-uninstaller)
$repository_folder/$(location_of_ --repo-program-directory)
END

   # Moves the cli-command to its destination.
   mv "$repository_folder/$repository_cli_directory/$(name_of_ --cli-command)" \
      "`location_of_ --cli-command-destination`"

   # Copies the libraries-directory to the CLI's supporting files folder. Moving the libraries
   # directory could disrupt the further execution of this script.
   cp -r "$repository_folder/$repository_cli_directory/`location_of_ --cli-libraries-directory`" \
      "$cli_supporing_files_destination"

   echo 'Installed Arduino Light Show CLI.'
   return 0
}


#-Main------------------------------------------#


declare_constants "$@"

# Makes sure the temporary working directory is always cleared upon exiting.
trap "rm -rf \"$working_directory\"" EXIT

# Sets up the installation environment including gaining access to the CLI's utility functions.
setup_installation_environment_ || exit 1 #RS=1
. "$repository_folder/$cli_utilities"
. "$repository_folder/$cli_constants"

# Sets up the CLI's supporting files folder and writes the path into the CLI-script.
setup_cli_supporting_files_folder_ || exit 2 #RS=2
complete_cli_script_ || exit 3 #RS=3

# Makes sure the Arduino-CLI is installed. If not, it's installed before continuing.
if ! silently- command -v arduino-cli; then
   install_arduino_cli_ || exit 4 #RS=4
   set_uninstall_ardunio_cli_flag_
fi

install_lightshow_cli

echo 'Installation complete.'
exit 0
