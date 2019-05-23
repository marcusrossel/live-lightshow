#!/bin/bash

# This script prints the info-file associated with a given server.
#
# Arguments:
# * <server name>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the given server name is undefined
# 3: the given server has no info-file


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 1 || exit 1

# Gets the server's static configuration file.
readonly static_config_file=$(fields_for_ config-file --with server-name "$1" --in static-index)

# Returns on failure if the given server name is undefined.
[ -z "$static_config_file" ] && exit 2

# Gets the server's info-file.
readonly info_file="$static_config_file$(name_for_ server-info-file-suffix)"

# Returns on failure if the given server does not have an info-file.
[ -f "$info_file" ] || exit 3

# Prints the server's info-file on a blank terminal "page".
clear; cat "$info_file"

exit 0
