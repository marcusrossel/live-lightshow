#!/bin/bash

# This script serves as a library of functions for accessing constants defined in the utility-files:
# * error_messages
# * file_locations
# * item_names
# * regular_expressions
# ... which are expected to be in a relative "Reference Files" directory.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$CLI_CONSTANTS_INCLUDED" ] && readonly CLI_CONSTANTS_INCLUDED=true || return

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)


#-Functions-------------------------------------#


# Prints all of the lines of <file> immediately following the line containing only <string> upto the
# next empty line or EOF. It is expected for there to be exactly one line containing only <string>.
# If the "--until"-flag and a following <delimiter> are passed, all lines are printed upto the next
# line only containing <delimiter>.
#
# Arguments:
# * <string>
# * <file>
# * <flag> optional, possible values: "--until"
# * <delimiter> required with <flag>
#
# Return status:
# 0: success
# 1: <flag> was invalid
# 2: <delimiter> was invalid (not passed)
# 3: there were less or more than one line exactly matching <string> in <file>
# 4: a custom <delimiter> was given, but never reached in <file>
function _lines_after_unique_ {
   # If a flag was passed, makes sure it is valid and a delimiter was passed, or prints an error and
   # returns on failure. A flag is also set in the process, indicating whether a <flag> was passed.
   if [ -n "$3" ]; then
      # Asserts flag validity.
      if [ "$3" != '--until' ]; then
         echo "Error: \`${FUNCNAME[0]}\` received invalid flag" >&2
         return 1
      fi

      # Asserts delimiter validity.
      if [ -z "$4" ]; then
         echo "Error: \`${FUNCNAME[0]}\` received invalid delimiter" >&2
         return 2
      fi

      local -r custom_delimiter=true
   else
      local -r custom_delimiter=false
   fi

   # Gets all of the lines in <file> exactly matching <string>.
   local -r match_line=`egrep -n "^$1\$" "$2"`

   # Makes sure that there was exactly one match line, or prints an error and returns on failure.
   if [ -z "$match_line" -o `wc -l <<< "$match_line"` -gt 1 ]; then
      echo "Error: \`${FUNCNAME[0]}\` did not match exactly one line" >&2
      return 3
   fi

   # Gets the line number immediately following the line of <string>'s match in <file>.
   local -r list_start=$[`cut -d : -f 1 <<< "$match_line"` + 1]

   # Prints all of the lines in <file> starting from "$list_start", until the delimiter line is
   # reached. If a custom delimiter is read, this is remembered by setting a flag.
   havent_read_custom_delimiter=true
   tail -n "+$list_start" "$2" | while read -r line; do
      if $custom_delimiter; then
         [ "$line" = "$4" ] && { havent_read_custom_delimiter=false; break; } || echo "$line"
      else
         [ -n "$line" ] && echo "$line" || break
      fi
   done

   # Makes sure a return on failure occurs if a custom delimiter was passed, but never read.
   $custom_delimiter && $havent_read_custom_delimiter && return 4

   return 0
}

# Prints the result of performing manual line continuation (on "\") in a given string.
#
# Arguments:
# * <string>
function _expand_line_continuations {
   # Iterates over the lines in the given string.
   while read -r line; do
      # If the last character in the line is "\", print neither it nor a trailing newline.
      [ "${line: -1}" = '\' ] && echo -ne "${line%?}" || echo -e "$line"
   done <<< "$1"

   return 0
}

# Prints the error message associated with a given flag.
# All messages are taken from a given file defaulting to <utility file: error messages>.
#
# Arguments:
# * <error message file> passed automatically by the alias
# * <flag>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <flag> is invalid
# 2: <error message file> does not contain <flag>'s identifier-string
alias message_for_="_message_for_ '$dot/Reference Files/error_messages' "
function _message_for_ {
   # The string used to search the error message file for a certain pattern.
   local message_identifier

   # Sets the search string according to the given flag, or prints an error and returns on failure
   # if an unknown flag was passed.
   case "$2" in
      --ct-malformed-configuratation)
         message_identifier='configure_thresholds.sh: Malformed Configuration:' ;;
      --ct-duplicate-identifiers)
         message_identifier='configure_thresholds.sh: Duplicate Identifier:' ;;
      --ct-no-arduino)
         message_identifier='configure_thresholds.sh: No Arduino:' ;;
      --ct-multiple-arduinos)
         message_identifier='configure_thresholds.sh: Multiple Arduinos:' ;;
      --lcli-usage)
         message_identifier='lightshow-cli: Usage:' ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$2\"" >&2
         return 1 ;;
   esac

   # Gets the lines following the search string in the error message file upto the line
   # containing only "MESSAGE-END", or returns on failure if that operation fails.
   if ! local -r message=`_lines_after_unique_ "$message_identifier" "$1" --until 'MESSAGE-END'`
   then return 2; fi

   # Performs manual line continuation.
   local -r expanded_message=`_expand_line_continuations "$message"`

   # Substitutes color variables declared in <utility file: error messages> for actual values and
   # prints the result.
   echo "$expanded_message" | sed \
      -e 's/RED>/\\033[0;31m/g' \
      -e 's/GREEN>/\\033[0;32m/g' \
      -e 's/YELLOW>/\\033[0;33m/g' \
      -e 's/NORMAL>/\\033[0;m/g'

   return 0
}

# Prints the constant string associated with the item of a given flag.
# All constants are taken from a given file defaulting to <utility file: item names>.
#
# Arguments:
# * <item name file> passed automatically by the alias
# * <flag>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <flag> is invalid
# 2: <item name file> does not contain <flag>'s identifier-string
alias name_of_="_name_of_ '$dot/Reference Files/item_names' "
function _name_of_ {
   # The string used to search the name-file for a certain pattern.
   local name_identifier

   # Sets the search string according to the given flag, or prints an error and returns on failure
   # if an unknown flag was passed.
   case "$2" in
      --cli-command)      name_identifier='CLI-command:'      ;;
      --arduino-uno-fbqn) name_identifier='Arduino-UNO FQBN:' ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$2\"" >&2
         return 1 ;;
   esac

   # Prints the lines following the search string in the name-file, or returns on failure if that
   # operation fails.
   _lines_after_unique_ "$name_identifier" "$1" || return 2

   return 0
}

# Prints the path of files/directories identified by a given flag.
# Paths to files/directories within the CLI-directory are given relative to the CLI-directory.
# Paths to files/directories within the repository but not the CLI-directory are given relative to
# the repository.
# Paths outside of the repository are given as absolute, with tilde expansion performed beforehand.
#
# All paths are taken from a given file defaulting to <utility file: file paths>.
#
# Arguments:
# * <file locations file> passed automatically by the alias
# * <flag>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <flag> is invalid
# 2: <file locations file> does not contain <flag>'s identifier-string
alias location_of_="_location_of_ '$dot/Reference Files/file_locations' "
function _location_of_ {
   # The string used to search the location-file for certain paths.
   local location_identifier

   # Sets the search string according to the given flag, or prints an error and returns on failure
   # if an unknown flag was passed.
   case "$2" in
      --repo-cli-directory)               location_identifier='Repo CLI-directory:'              ;;
      --repo-program-directory)           location_identifier='Repo Program-directory:'          ;;
      --cli-uninstaller)                  location_identifier='CLI Uninstaller:'                 ;;
      --cli-scripts-directory)            location_identifier='CLI Scripts-directory:'           ;;
      --cli-libraries-directory)          location_identifier='CLI Libraries-directory:'         ;;
      --cli-command-destination)          location_identifier='CLI-command destination:'         ;;
      --cli-supporting-files-destination) location_identifier='CLI-supporting files destination:';;
      --arduino-cli-source)               location_identifier='Arduino-CLI source:'              ;;
      --arduino-cli-destination)          location_identifier='Arduino-CLI destination:'         ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$2\"" >&2
         return 1 ;;
   esac

   # Gets the lines matched in the location-file for the given identifier, or returns on failure if
   # that operation fails.
   local -r raw_paths=`_lines_after_unique_ "$location_identifier" "$1"` || return 2

   # Performs explicit tilde expansion and prints the resulting paths.
   while read path; do
      [ "${path:0:1}" = '~' ] && echo "$HOME${path:1}" || echo "$path"
   done <<< "$raw_paths"

   return 0
}

# Prints the regular expression pattern used to match a type of item identified by a given flag.
# All patterns are taken from a given file defaulting to <utility file: regular expressions>.
#
# Arguments:
# * <regular expression file> passed automatically by the alias
# * <flag>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <flag> is invalid
# 2: <regular expression file> does not contain <flag>'s identifier-string
alias regex_for_="_regex_for_ '$dot/Reference Files/regular_expressions' "
function _regex_for_ {
   # The string used to search the regex-file for a certain pattern.
   local regex_identifier

   # Sets the search string according to the given flag, or prints an error and returns on failure
   # if an unknown flag was passed.
   case "$2" in
      --header-candidate)
         regex_identifier='Threshold declaration header candidate:' ;;
      --header)
         regex_identifier='Threshold declaration header:' ;;
      --body)
         regex_identifier='Threshold declaration body:' ;;
      --end-tag)
         regex_identifier='Threshold declarations end tag:' ;;
      --configuration-entry)
         regex_identifier='Threshold configuration entry:' ;;
      --uninstall-arduino-cli-flag-tag)
         regex_identifier='Uninstall Arduino-CLI flag tag:' ;;
      --cli-supporting-files-folder-tag)
         regex_identifier='CLI supporting files folder tag:' ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$2\"" >&2
         return 1 ;;
   esac

   # Prints the lines following the search string in the regex-file, or returns on failure if that
   # operation fails.
   _lines_after_unique_ "$regex_identifier" "$1" || return 2

   return 0
}
