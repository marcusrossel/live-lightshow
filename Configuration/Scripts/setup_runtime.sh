#!/bin/bash

# This script gets the user configuration from the user, creates the runtime index, and sets up the
# runtime configuration files.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: the user chose to quit


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting and lookup utilities.
. "$dot/../../Utilities/scripting.sh"
. "$dot/../../Utilities/lookup.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1

# Writes a new runtime index.
readonly runtime_index="$dot/../../$(path_for_ runtime-index)"
"$dot/write_runtime_index_into.sh" "$runtime_index" || exit 2

# Updates the runtime configuration directory.
"$dot/setup_runtime_configuration_files.sh"

exit 0
