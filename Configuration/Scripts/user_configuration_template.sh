#!/bin/bash

# This script generates a template which can be displayed to the user when retrieving their desired
# instance-ID to server-type(server ID) mapping.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting and lookup utilities.
. "$dot/../../Utilities/scripting.sh"
. "$dot/../../Utilities/lookup.sh"
. "$dot/../../Utilities/index.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1

# Prints the user configuration template.
echo "$(text_for_ uct-template)"

# Prints the server-identifiers contained in static index in the form:
# # * <server ID 1>
# # * <server ID 2>
# ...
column_for_ server-id --in static-index | while read server_id; do echo "# * $server_id"; done

# Adds a trailing newline.
echo

exit 0
