#!/bin/bash

# This script adds a given server file to the set of servers - if possible.
#
# Arguments:
# * <server file>
# * <custom server name> optional
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the server name (or if given, the custom server name) is already in use
# 3: the given server file is malformed


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 1 2 '<server file> <custom server name: optional>' || exit 1
