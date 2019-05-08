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


#-Constants-------------------------------------#


readonly newline=$'\n'

# Declares color codes for printing.
readonly print_red='\033[0;31m'
readonly print_green='\033[0;32m'
readonly print_yellow='\033[0;33m'
readonly print_normal='\033[0m'


#-Functions-------------------------------------#


# Prints an error to stderr formatted according to a given flag for a given problem item.
#
# Arguments:
# * <error source script> passed automatically by the alias
# * <error source line> passed automatically by the alias
# * <error source function> passed automatically by the alias
# * <message> or <type flag> possible values: "--internal", "--identifier", "--flag"
# * <problem item> required if <type flag> was passed
alias print_error_for='_print_error_for "${BASH_SOURCE[0]}" "${LINENO[0]}" "${FUNCNAME[0]}" '
function _print_error_for {
   # Prints the exact location of the call site of this error.
   local -r script="$print_yellow$(basename "$1")$print_normal"
   local -r line="$print_yellow$2$print_normal"
   local -r function="$print_yellow${3:-main}$print_normal"
   echo -e "${print_red}Error$print_normal: $script: $line: $function:" >&2

   case "$4" in
      --internal)
         echo -e " Internal error." >&2 ;;
      --identifier|--flag)
         echo -e " > Received invalid ${4:2} '$print_yellow$5$print_normal'." >&2 ;;
      *)
         shift 3
         echo -e "$@" >&2 ;;
   esac

   return 0
}

# Prints a string identifying the current operating system.
#
# Possible return values are: "linux", "macOS", "win10"
#
# Return status:
# 0: success
# 1: unknown operating system
function current_OS_ {
   case "$OSTYPE" in
      linux-gnu)
         # The Windows subsystem for Linux also returns 'linux-gnu', so we have to check again.
         if egrep -i 'Microsoft' /proc/sys/kernel/osrelease &>/dev/null; then
            echo 'win10'
         else
            echo 'linux'
         fi ;;
      darwin*)
         echo 'macOS' ;;
      *)
         return 1 ;;
   esac

   return 0
}

# Prints the given range of lines in a given string or file.
#
# Arguments:
# * <line number>
# * <search object type flag>, possible values: "--in-file", "--in-string"
# * <string/file>
# or
# * <range start>
# * <to flag>
# * <range end>
# * <search object type flag>, possible values: "--in-file", "--in-string"
# * <string/file>
#
# Return status:
# 0: success
# 1: received invalid <to flag> or <search object type flag>
# 2: the given range start was greater than the range end
function line_ {
   # Handels a different call-signature, based on which flag was passed as second argument.
   case "$2" in
      # Call signature 1.
      --in-file|--in-string)
         local tail_value=$1
         local head_value=1
         local search_object_type=$2
         local search_object=$3 ;;

      # Call signature 2.
      --to)
         # Makes sure that the given range start comes before the range end.
         [ "$1" -le "$3" ] || return 2

         local tail_value=$1
         local head_value=$(($3 - $1 + 1))
         local search_object_type=$4
         local search_object=$5 ;;

      *)
         print_error_for --flag "$2"; return 1 ;;
   esac

   # Prints the previously determined line-range.
   case "$search_object_type" in
      --in-file) tail -n "+$tail_value" "$search_object" | head -n "$head_value" ;;
      --in-string) echo "$search_object" | tail -n "+$tail_value" | head -n "$head_value" ;;
      *) print_error_for_ --flag "$4"; return 1 ;;
   esac

   return 0
}

# Returns the literal 'true' of 'false', depending on whether a given string is a line is a given
# string or file.
#
# Arguments:
# * <string>
# * <search object type flag>, possible values: "--is-line-in-file", "--is-line-in-string"
# * <line source>
#
# Returns:
# 0: success
# 1: received invalid <search object type flag>
function string_ {
   case "$2" in
      --is-line-in-file)   local -r search_space=$(cat "$3") ;;
      --is-line-in-string) local -r search_space=$3 ;;
      *) print_error_for_ --flag "$2"; return 1 ;;
   esac

   # Prints "true" and returns if a line in $search_space matched <string>.
   while read line; do
      [ "$line" = "$1" ] && { echo 'true'; return 0; }
   done <<< "$search_space"

   # Prints "false" if <string> was not a line in $search_space.
   echo 'false'
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
function line_numbers_of_string_ {
   case "$2" in
      --in-file)   local -r search_space=$(cat "$3") ;;
      --in-string) local -r search_space=$3 ;;
      *) print_error_for_ --flag "$2"; return 1 ;;
   esac

   local line_counter=1
   while read line; do
      [ "$line" == "$1" ] && echo $line_counter
      ((line_counter++))
   done <<< "$search_space"

   return 0
}

# Prints the given string without leading and trailing whitespace (on each line).
# If no string is passed stdin will be used as input.
#
# Arguments:
# * <string> passable via stdin
function trimmed {
   if [ -n "$1" ]; then
      awk '{$1=$1};1' <<< "$1"
   else
      cat | awk '{$1=$1};1'
   fi

   return 0
}

# Prints the search or replacement pattern of a given literal string, that is safe to use as literal
#  with sed (stream editor).
#
# Arguments:
# * <type flag> possible values: "-s", "-r", "--search-string", "--replacement"
# * <literal string>
#
# Return status:
# 0: success
# 1: the given <type flag> was invalid
function sed_safe_ {
   case "$1" in
      -s|--search-string) sed -e 's/[]\/$*.^[]/\\&/g' <<< "$2" ;;
      -r|--replacement)   sed -e 's/[\/&]/\\&/g' <<< "$2" ;;
      *) print_error_for_ --flag "$1"; return 1 ;;
   esac
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
alias assert_correct_argument_count_='_assert_correct_argument_count_ "${BASH_SOURCE[0]##*/}" "$#" '
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
      echo -e "Usage: '$print_yellow$1$print_normal' expects no arguments" >&2
   else
      echo -e "Usage: $print_yellow$1$print_normal $usage_pattern" >&2
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
