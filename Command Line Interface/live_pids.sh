#!/bin/bash

# This script prints a list of the PIDs associated with a currently running lightshow.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments

#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../Utilities/scripting.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1

# Prints all of the PIDs of processes containing some reference to "--sketch" or "--sketch-path"
# being this project's directory.
ps | egrep -e "--sketch(-path)?=$(realpath "$dot/..")" | egrep -o '^\s*[0-9]+'

exit 0
