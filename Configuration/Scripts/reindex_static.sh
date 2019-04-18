#!/bin/bash

# This script generates a new static index and with a corresponding static configuration directory.
# Older, unused configuration files will remain in the static configuration directory, but will not
# affect anything.
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


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1

# Writes a new static index.
readonly static_index="$dot/../../$(path_for_ static-index)"
"$dot/static_index.sh" >"$static_index"

# Updates the static configuration directory.
"$dot/setup_static_configuration_files.sh"

exit 0
