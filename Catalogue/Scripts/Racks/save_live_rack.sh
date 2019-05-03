#!/bin/bash

# This script captures the current setup of a running live show and saves it as a rack with a given
# name.
#
# Arguments:
# * <rack name>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the given name is malformed
# 3: the given name is already in use


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/index.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly given_rack_name=$1

   return 0
}


#-Functions-------------------------------------#



#-Main------------------------------------------#


assert_correct_argument_count_ 1 '<rack identifier>' || exit 1
declare_constants_ "$@"
