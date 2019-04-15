#!/bin/bash

# This script returns certain values associated with a connected Arduino, based on a given flag.
#
# Arguments:
# <trait flag>, possible values: "--fqbn", "--port"
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: <trait flag> was invalid
# 3: no Arduino could be found
# 4: multiple Arduinos were found

# TODO: This is slow, so allow multiple flags at once.


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports CLI utilities.
. "$_dot/../Libraries/utilities.sh"
. "$_dot/../Libraries/constants.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Main------------------------------------------#


assert_correct_argument_count_ 1 '<trait flag>' || exit 1 #RS=1
# Prints an error and returns on failure if the <trait flag> is invalid.
if ! [ "$1" = '--fqbn' -o "$1" = '--port' ]; then
   echo "Error: \`${BASH_SOURCE[0]}\` received invalid flag \"$1\"" >&2
   exit 2 #RS=2
fi

# Gets a list of the boards connected to the Arduino. The format is:
# <FQBN 1>   <Port 1>	<ID 1>   <Board Name 1>
# <FQBN 2>   <Port 2>	<ID 2>   <Board Name 2>
# ...        ...        ...      ...
readonly board_list=`silently- --stderr arduino-cli board list | tail -n +2`

# Prints an error message and returns on failure if no, of multiple Arduinos were found.
if [ -z "$board_list" ]; then
   echo 'Error: could not find any connected Arduino' >&2
   exit 3 #RS=3
elif [ "`wc -l <<< "$board_list"`" -gt 1 ]; then
   echo 'Error: multiple Arduinos were found' >&2
   exit 4 #RS=4
fi

# Gets the FQBN and port of the connected Arduino.
read -a components <<< "$board_list"

# Prints the component corresponding to the given <trait flag>, or prints an error and returns on
# failure if the given <trait flag> was invalid.
case "$1" in
   --fqbn) echo "${components[0]}" ;;
   --port) echo "${components[1]}" ;;
   *) echo 'Internal error'; exit 5 ;; # This point should be unreachable.
esac

exit 0
