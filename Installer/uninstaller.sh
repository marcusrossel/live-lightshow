#!/bin/bash

# This script uninstalls all of the components installed for the Arduino Light Show CLI to run.
# This includes:
# * the Arduino Light Show CLI script
# * the Arduino Light Show CLI's supporting files
# * the Arduino CLI, if it had to be installed by the installer script
# Any of these files are only moved to the trash-folder, so the process can be undone manually.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the current OS does not allow for uninstallation
# 3: the user does not want to uninstall


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports CLI utilities.
. "$_dot/Libraries/utilities.sh"
. "$_dot/Libraries/constants.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
#
# Return status:
# 0: success
# 1: the script is running on something else than macOS or Linux
function declare_constants_ {
   # A flag set by the installer script, determining whether the Arduino CLI should be deleted upon
   # uninstallation as well.
   # UNINSTALL-ARDUINO-CLI-FLAG
   readonly should_uninstall_arduino_cli=false

   # Sets the trash-folder path according to the operating system. If an unknown operating system is
   # encountered an error is printed and a return on status 1 occurs.
   case "`uname -s`" in
      Darwin*) readonly trash="$HOME/.Trash" ;;
       Linux*) readonly trash="/home/$USER/.local/share/Trash" ;;
            *)
         echo 'Error: uninstallation is not possible on the current operating system'
         return 1 ;;
   esac

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1 #RS=1
declare_constants_ "$@" || exit $[$?+1] #RS+1=2

# Gets confirmation from the user that uninstallation should be performed. If approval is not given
# an exit on status 1 occurs.
echo 'Are you sure you want to uninstall the Arduino Light Show CLI? [y or n]'
succeed_on_approval_ || exit 3 #RS=3

# Deletes the Arduino CLI as specified by <utility file: file locations>, if the "uninstall Arduino
# CLI"-flag is set.
if $should_uninstall_arduino_cli; then
   echo 'Uninstalling Arduino CLI...'

   # Gets the FQBN of the Arduino UNO.
   local -r uno_fqbn=`name_of_ --arduino-uno-fbqn`
   # Uninstalls the Arduino-UNO board core.
   silently- arduino-cli core install "$uno_fqbn"

   # Moves the Arduino CLI to the trash.
   silently- mv -f "`location_of_ --arduino-cli-destination`" "$trash"
fi

echo 'Uninstalling Arduino Light Show CLI...'
# Deletes the CLI script as specified by <utility file: file locations>.
silently- mv -f "`location_of_ --cli-command-destination`/`name_of_ --cli-command`" "$trash"

# Gets the name of the CLI's supporting file directory folder.
readonly cli_supporing_files_folder=$(basename "$(location_of_ --cli-supporting-files-destination)")
# Removes any directory in the trash folder of the same name as the CLI's supporting file directory.
[ -d "$trash/$cli_supporing_files_folder" ] && rm -r "$trash/$cli_supporing_files_folder"

# Deletes the CLI's supporting files folder as specified by <utility file: file locations>.
silently- mv "`location_of_ --cli-supporting-files-destination`" "$trash"

echo 'Uninstallation complete.'
exit 0
