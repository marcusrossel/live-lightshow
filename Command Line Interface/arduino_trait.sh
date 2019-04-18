#!/bin/bash

# This script returns certain values associated with a connected Arduino, based on given flags.
# If multiple flags are given, the results are printed in the same order.
#
# Arguments:
# <trait flag 1>, possible values: "--fqbn", "--port"
# <trait flag 2> optional, possible values: "--fqbn", "--port"
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: <trait flag 1> or <trait flag 2> was invalid
# 3: the user chose to quit


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports lookup and utilities.
. "$_dot/../Utilities/lookup.sh"
. "$_dot/../Utilities/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Main------------------------------------------#


assert_correct_argument_count_ 1 2 '<trait flag 1>' '<trait flag 2>' || exit 1

# Checks the given flag(s) for validity.
for flag in "$@"; do
   # Prints an error and returns on failure if the flag is invalid.
   case "$flag" in
      --fqbn|--port) continue ;;
      *) echo "Error: \`${BASH_SOURCE[0]}\` received invalid flag \"$flag\"" >&2
         exit 2 ;;
   esac
done

# Loops until there is exactly on Arduino connected or the user quits.
while true; do
   # Gets a list of the boards connected to the Arduino. The format is:
   # <FQBN 1>   <Port 1>	<ID 1>   <Board Name 1>
   # <FQBN 2>   <Port 2>	<ID 2>   <Board Name 2>
   # ...        ...        ...      ...
   board_list=$(silently- --stderr arduino-cli board list | tail -n +2)

   # Prints an error message and returns on failure if no, of multiple Arduinos were found.
   # Otherwise the while-loop is exited.
   if [ -z "$board_list" ]; then
      error_message=$(message_for_ at-no-arduino)
   elif [ "$(wc -l <<< "$board_list")" -gt 1 ]; then
      error_message=$(message_for_ at-multiple-arduinos)
   else
      break
   fi

   # Prints an error message and prompts the user to un-/replug the Arduino or exit.
   clear >&2
   echo -e "$error_message" >&2
   echo -e "\n${print_green}Do you want to try again? [y or n]$print_normal" >&2
   succeed_on_approval_ || exit 3
done

# Gets the FQBN and port of the connected Arduino.
read -a components <<< "$board_list"

# Prints the components corresponding to the given trait flag, sequentially.
for flag in "$@"; do
   case "$flag" in
      --fqbn) echo "${components[0]}" ;;
      --port) echo "${components[1]}" ;;

      # Should be unreachable.
      *) echo "Error: \`${BASH_SOURCE[0]}\` received invalid flag \"$flag\"" >&2
         exit 2 ;;
   esac
done

exit 0
