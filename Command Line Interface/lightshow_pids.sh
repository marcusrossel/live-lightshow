#!/bin/bash

# This script prints a list of the PIDs associated with a currently running lightshow.


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")


#-Main------------------------------------------#


# Prints all of the processes containing some reference to "--sketch" or "--sketch-path" being this
# project's directory.
ps | egrep -e "--sketch(-path)?=$(realpath "$dot/..")" | egrep -o '^\s*[0-9]+'

exit 0
