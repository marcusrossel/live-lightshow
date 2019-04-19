#!/bin/bash

# This script serves as a library of functions to be used by other scripts. It can be "imported" via
# sourcing.
# It should be noted that this script activates alias expansion.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$SCRIPTING_SH" ] && readonly SCRIPTING_SH=true || return

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Saves the previous value of the $dot-variable.
previous_dot="$dot"
# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)


#-Constants-------------------------------------#


# Declares color codes for printing.
readonly print_red='\033[0;31m'
readonly print_green='\033[0;32m'
readonly print_yellow='\033[0;33m'
readonly print_normal='\033[0m'

# Declares OS-name variables.
readonly linux_OS='linux'
readonly macOS_OS='macOS'
readonly win10_OS='win10'


#-Functions-------------------------------------#


# Prints a string identifying the current operating system.
#
# Possible return values are: $linux_OS, $macOS_OS, $win10_OS
#
# Return status:
# 0: success
# 1: unknown operating system
function current_OS_ {
   case "$OSTYPE" in
      linux-gnu)
         # The Windows subsystem for Linux also returns 'linux-gnu', so we have to check again.
         if egrep -i 'Microsoft' /proc/sys/kernel/osrelease &>/dev/null; then
            echo "$win10_OS"
         else
            echo "$linux_OS"
         fi ;;
      darwin*)
         echo "$macOS_OS" ;;
      *)
         return 1 ;;
   esac

   return 0
}

# Prints the line at a given line number in a given string or file.
#
# Arguments:
# * <line number>
# * <search object type flag>, possible values: "--in-file", "--in-string"
# * <string/file>
#
# Return status:
# 0: success
# 1: received invalid <search object type flag>
function line_ {
   case "$2" in
      --in-file)   tail -n "+$1" "$3"     | head -n 1 ;;
      --in-string) tail -n "+$1" <<< "$3" | head -n 1 ;;
      *) echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$2\"" >&2
         return 1 ;;
   esac

   return 0
}

# Prints the line numbers of all of the lines in a given list of lines equal to a given string or
# file. If none is found a return on failure occurs.
#
# Arguments:
# * <string>
# * <search object type flag>, possible values: "--in-file", "--in-string"
# * <line source>
#
# Returns:
# 0: success
# 1: received invalid <search object type flag>
# 2: no line found equal to <string>
function line_numbers_of_string_ {
   case "$2" in
      --in-file)   local -r search_space=$(cat "$3") ;;
      --in-string) local -r search_space=$3 ;;
      *) echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$2\"" >&2
         return 1 ;;
   esac

   local return_status=2
   local line_counter=1

   while read line; do
      if [ "$line" == "$1" ]; then
         echo $line_counter
         return_status=0
      fi

      ((line_counter++))
   done <<< "$search_space"

   return $return_status
}

# Checks the given number of command line arguments is equal to a given expected range of them.
# If not, prints an error message containing the given correct usage pattern and returns on failure.
# If the expected number of arguments is not a range, the upper bound can be omitted.
# If the expected number of command line arguments is `0` a custom message will be printed, so the
# correct usage pattern string can be omitted.
#
# Arguments:
# * <script name> passed automatically by the alias
# * <actual number of command line arguments> passed automatically by the alias
# * <minimum expected number of command line arguments>
# * <maximum expected number of command line arguments> case-optional
# * <correct usage pattern> case-optional
#
# Return status:
# 0: success
# 1: the number arguments does not match the expected number
alias assert_correct_argument_count_='_assert_correct_argument_count_ "${BASH_SOURCE##*/}" "$#" '
function _assert_correct_argument_count_ {
   # Sets up the <minimum expected number of command line arguments>, <maximum expected number of
   # command line arguments> and <correct usage pattern>, accoring to whether an upper bound was
   # given or not.
   local -r expected_minimum=$3
   case "$4" in
      # Handels the cases where "$4" is not a number.
      ''|*[!0-9]*) local -r expected_maximum=$3; local -r usage_pattern=$4 ;;
      # Handels the cases where "$4" is not, not a number.
      *) local -r expected_maximum=$4; local -r usage_pattern=$5 ;;
   esac

   # Checks whether the  <actual number of command line arguments> is in the range of <minimum
   # expected number of command line arguments> and <maximum expected number of command line
   # arguments>. If not an error is printed and return on failure occurs.
   [ "$2" -ge "$expected_minimum" -a "$2" -le "$expected_maximum" ] && return 0

   # Prints a different error message if the <expected number of command line arguments> is `0`.
   if [ "$3" -eq 0 ]; then
      echo -e "Usage: $print_yellow$1$print_normal expects no arguments" >&2
   else
      echo -e "Usage: $print_yellow$1$print_normal $4" >&2
   fi
   echo "Consult the script's source for further documentation." >&2

   return 1
}

# Runs a given command while removing the output streams specified by a flag. If no flag is passed,
# stdout and stderr are silenced.
#
# Arguments:
# * <flag> optional, possible values: "--stderr", "--stdout"
# * <command> including all of its arguments
#
# Return status:
# $? of <command>
function silently- {
   # Runs <command> and redirects output differently depending on the given <flag>.
   case "$1" in
      --stdout) shift; "$@" 1>/dev/null ;;
      --stderr) shift; "$@" 2>/dev/null ;;
             *)        "$@" &>/dev/null ;;
   esac

   # Propagates the return status of <command>.
   return $?
}

# Returns the commands associated with the trap for a given signal in the current shell.
#
# Arguments:
# * <trap signal>
#
# Return status:
# 0: success
# 1: <trap signal> is not valid
function commands_for_trap_with_signal_ {
   # Makes sure <trap signal> is valid.
   trap -p "$1" &>/dev/null || return 1

   # Gets a string containing the commands currently associated with the trap with <trap signal>.
   local -r raw_commands=$(trap -p "$1")
   # Removes the `trap -p`-prefix from the string.
   local -r prefixless_commands=$(sed -e "1s/^[^']*'//g" <<< "$raw_commands")
   # Removes the `trap -p`-suffix from the prefixless string.
   local -r commands=$(sed -e "\$ s/'[^']*\$//g" <<< "$prefixless_commands")

   # Prints the commands and returns successfully.
   echo "$commands"
   return 0
}

# Prompts the user for input until either [y] or [n] is pressed. If [y] is pressed, the function
# returns successfully, otherwise it returns on failure.
#
# Return status:
# 0: the user pressed [y]
# 1: the user pressed [n]
function succeed_on_approval_ {
   while true; do
      # Tries to read exactly one character and tries again right away if that did not work.
      read -s -n 1 || continue

      # Checks for [y] or [n] and returns if either one of them was entered.
      case $REPLY in
         'y'|'Y') return 0 ;;
         'n'|'N') return 1 ;;
      esac
   done
}


#-Cleanup---------------------------------------#


# Resets the $dot-variable to its previous value.
dot="$previous_dot"
