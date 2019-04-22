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
# 4: internal error


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting and lookup utilities.
. "$dot/../Utilities/scripting.sh"
. "$dot/../Utilities/lookup.sh"


#-Main------------------------------------------#


assert_correct_argument_count_ 1 2 '<trait flag 1>' '<trait flag 2>' || exit 1

# Checks the given flag(s) for validity.
for flag in "$@"; do
   # Prints an error and returns on failure if the flag is invalid.
   case "$flag" in
      --fqbn|--port) continue ;;
      *) print_error_for --flag "$flag"; exit 2 ;;
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
      error_message=$(text_for_ at-no-arduino)
   elif [ "$(wc -l <<< "$board_list")" -gt 1 ]; then
      error_message=$(text_for_ at-multiple-arduinos)
   else
      break
   fi

   # Prints an error message and prompts the user to un-/replug the Arduino or exit.
   clear >&2
   echo -e "$error_message" >&2
   echo -e "\n${print_green}Do you want to try again? [y or n]$print_normal" >&2
   succeed_on_approval_ || exit 3
done

# Gets the traits of the connected Arduino in an array.
read -a components <<< "$board_list"

# Prints the components corresponding to the given trait flag, sequentially.
for flag in "$@"; do
   case "$flag" in
      --fqbn) echo "${components[0]}" ;;
      --port) echo "${components[1]}" ;;
      *) print_error_for --internal; exit 4 ;; # Should be unreachable.
   esac
done

exit 0
