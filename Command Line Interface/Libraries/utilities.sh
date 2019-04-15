#!/bin/bash

# This script serves as a library of functions to be used by other scripts in the CLI. It can be
# "imported" via sourcing.
# It should be noted that this script activates alias expansion.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$CLI_UTILITIES_INCLUDED" ] && readonly CLI_UTILITIES_INCLUDED=true || return

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)


#-Constants-------------------------------------#


# Declares color codes for printing.
readonly print_red='\033[0;31m'
readonly print_green='\033[0;32m'
readonly print_yellow='\033[0;33m'
readonly print_normal='\033[0m'


#-Functions-------------------------------------#


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
   local -r raw_commands=`trap -p "$1"`
   # Removes the `trap -p`-prefix from the string.
   local -r prefixless_commands=`sed -e "1s/^[^']*'//g" <<< "$raw_commands"`
   # Removes the `trap -p`-suffix from the prefixless string.
   local -r commands=`sed -e "\$ s/'[^']*\$//g" <<< "$prefixless_commands"`

   # Prints the commands and returns successfully.
   echo "$commands"
   return 0
}

# Returns on failure if a given <string> is not a path to an existing readable file.
# If the <flag> is passed as last argument, the file is is also checked for the ".ino"-extension.
#
# Arguments:
# * <script name> passed automatically by the alias
# * <string>
# * <flag> optional, possible values: "--ino"
#
# Return status:
# 0: success
# 1: the given string is not a path to an existing readable file
# 2: the given <flag> is invalid
# 3: the <flag> was passed and the given path is not a `.ino`-file
alias assert_path_validity_='_assert_path_validity_ "${BASH_SOURCE##*/}" '
function _assert_path_validity_ {
   # Makes sure the given string is a path to an existing readable file, or prints an error and
   # returns on failure.
   if ! [ -f "$2" -a -r "$2" ]; then
      echo "Error: \"$2\" is not an existing readable file" >&2
      return 1
   fi

   # Checks if a <flag> was passed.
   if [ -n "$3" ]; then
      # Makes sure the flag is valid or prints an error and returns on failure.
      if [ "$3" != '--ino' ]; then
         echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$3\"" >&2
         return 2
      fi

      # Makes sure the given <string> ends in ".ino", or prints an error and returns on failure.
      if [ "${2: -4}" != '.ino' ]; then
         echo "Error: \"$2\" is not a \`.ino\`-file" >&2
         return 3
      fi
   fi

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
