#!/bin/bash

# This script gets parameters needed to and starts the lightshow-program.
#
# Return status:
# 0: success
# 1: the user chose to quit


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports CLI utilities.
. "$_dot/../Libraries/utilities.sh"
. "$_dot/../Libraries/constants.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly arduino_port=`"$dot/arduino_trait.sh" --port`; [ $? -eq 3 ] && exit 1

   local -r program_directory="$dot/../../`location_of_ --repo-program-directory`"
   readonly lightshow_program_folder="$program_directory/`location_of_ --lightshow-program`"

   readonly config_file="$dot/../`location_of_ --cli-program-config-file`"
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1 #RS=1
declare_constants "$@"



processing-java --sketch="$lightshow_program_folder" --run "$arduino_port" "$config_file" \
&>/dev/null &
