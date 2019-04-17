#!/bin/bash

# This script serves as a library of functions for conveniently accessing this project's lookup
# files. It can be "imported" via sourcing.
# The files are expected to be in the same directory as this script.
# It should be noted that this script activates alias expansion.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$LOOKUP_SH" ] && readonly LOOKUP_SH=true || return

# Turns on alias-expansion explicitly, as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports the utility script.
. "$_dot/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Private-Functions-----------------------------#


# Prints all of the lines of <file> immediately following the line containing only <string> upto a
# certain delimiter.
# It is expected for there to be exactly one line containing only <string>.
# By default the delimiter is an empty line or EOF. If the "--until"-flag and a following
# <delimiter> are passed, all lines are printed upto the next line only containing <delimiter>.
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
   local -r match_line=$(egrep -n "^$1\$" "$2")

   # Makes sure that there was exactly one match line, or prints an error and returns on failure.
   if [ -z "$match_line" -o $(wc -l <<< "$match_line") -gt 1 ]; then
      echo "Error: \`${FUNCNAME[0]}\` did not match exactly one line with \"$1\"" >&2
      return 3
   fi

   # Gets the line number immediately following the line of <string>'s match in <file>.
   local -r match_line_number=$(cut -d : -f 1 <<< "$match_line")
   local -r list_start=$((match_line_number + 1))

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


#-Public-Functions------------------------------#


# Prints the URL associated with a given identifier, adapted to the current operating system.
# All constants are taken from a given file defaulting to <lookup file: dependency urls>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <item name file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <item name file> does not contain <identifier>'s identifier-string
alias url_for_="_url_for_ '$dot/../../Lookup Files/dependency-urls' "
function _url_for_ {
   # The string used to search the lookup file for a certain pattern.
   local url_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      arduino-processing-lib) url_identifier='Arduino Processing library:' ;;
      standard-firmata-raw)   url_identifier='StandardFirmata raw:'        ;;
      ddfs-minim-lib)         url_identifier="ddf's Minim library:"        ;;
      arduino-cli)            url_identifier="Arduino-CLI $(current_OS_):" ;;
      processing)             url_identifier="Processing $(current_OS_):"  ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$2\"" >&2
         return 1 ;;
   esac

   # Prints the lines following the search string in the lookup file, or returns on failure if that
   # operation fails.
   _lines_after_unique_ "$url_identifier" "$1" || return 2

   return 0
}

# Prints the error message associated with a given identifier.
# All messages are taken from a given file defaulting to <lookup file: error messages>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <error message file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <error message file> does not contain <identifier>'s identifier-string
alias message_for_="_message_for_ '$dot/../../Lookup Files/error-messages' "
function _message_for_ {
   # The string used to search the lookup file for a certain pattern.
   local message_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      ct-malformed-configuration)
         message_identifier='configure_thresholds.sh: Malformed Configuration:' ;;
      ct-duplicate-identifiers)
         message_identifier='configure_thresholds.sh: Duplicate Identifier:' ;;
      at-no-arduino)
         message_identifier='arduino_trait.sh: No Arduino:' ;;
      at-multiple-arduinos)
         message_identifier='arduino_trait.sh: Multiple Arduinos:' ;;
      lightshow-usage)
         message_identifier='lightshow: Usage:' ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$2\"" >&2
         return 1 ;;
   esac

   # Gets the lines following the search string in the lookup file upto the line containing only
   # "MESSAGE-END", or returns on failure if that operation fails.
   if ! local -r message=$(_lines_after_unique_ "$message_identifier" "$1" --until 'MESSAGE-END')
   then return 2; fi

   # Performs manual line continuation.
   local -r expanded_message=$(_expand_line_continuations "$message")

   # Substitutes color variables declared in <lookup file: error messages> for actual values and
   # prints the result.
   echo "$expanded_message" | sed \
      -e 's/RED>/\\033[0;31m/g' \
      -e 's/GREEN>/\\033[0;32m/g' \
      -e 's/YELLOW>/\\033[0;33m/g' \
      -e 's/NORMAL>/\\033[0;m/g'

   return 0
}

# Prints the constant string associated with a given identifier.
# All constants are taken from a given file defaulting to <lookup file: item names>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <item name file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <item name file> does not contain <identifier>'s identifier-string
alias name_for_="_name_for_ '$dot/../../Lookup Files/item-names' "
function _name_for_ {
   # The string used to search the lookup file for a certain pattern.
   local name_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      arduino-cli)              name_identifier='Arduino-CLI:'                          ;;
      processing)               name_identifier='Processing:'                           ;;
      processing-executable)    name_identifier="Processing executable $(current_OS_):" ;;
      processing-lib-directory) name_identifier='Processing library directory:'         ;;
      arduino-processing-lib)   name_identifier='Arduino Processing library:'           ;;
      ddfs-minim-lib)           name_identifier="ddf's Minim library:"                  ;;
      lightshow-program)        name_identifier='Lightshow program:'                    ;;
      arduino-uno-fbqn)         name_identifier='Arduino-UNO FQBN:'                     ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$2\"" >&2
         return 1 ;;
   esac

   # Prints the lines following the search string in the lookup file, or returns on failure if that
   # operation fails.
   _lines_after_unique_ "$name_identifier" "$1" || return 2

   return 0
}

# Prints the path of the file/directory associated with a given identifier, adapted to the current
# operating system. There may be multiple paths printed, in which case they are on a seperate line
# each.
# All paths are taken from a given file defaulting to <lookup file: file paths>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <file locations file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <file locations file> does not contain <identifier>'s identifier-string
alias path_for_="_path_for_ '$dot/../../Lookup Files/file-paths' "
function _path_for_ {
   # The string used to search the lookup file for certain paths.
   local path_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      delete-with-install)             path_identifier='Delete with installation:'               ;;
      cli-command-source)              path_identifier='CLI-command source:'                     ;;
      lightshow-directory)             path_identifier='Lightshow program directory:'            ;;
      servers-directory)               path_identifier='Servers directory:'                      ;;
      firmata-directory)               path_identifier='StandardFirmata program directory:'      ;;
      server-id-class-map)             path_identifier='Server ID-class map:'                    ;;
      server-instance-id-map)          path_identifier='Server instance-ID map:'                 ;;
      server-instance-runtime-map)     path_identifier='Server instance-runtime map:'            ;;
      runtime-configuration-directory) path_identifier='Runtime configuration directory:'        ;;
      cli-command-destination)         path_identifier='CLI-command destination:'                ;;
      arduino-cli-destination)         path_identifier='Arduino-CLI destination:'                ;;
      app-directory)                   path_identifier="Application directory $(current_OS_):"   ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$2\"" >&2
         return 1 ;;
   esac

   # Gets the lines matched in the location-file for the given identifier, or returns on failure if
   # that operation fails.
   local -r raw_paths=$(_lines_after_unique_ "$path_identifier" "$1") || return 2

   # Performs explicit tilde expansion and prints the resulting paths.
   while read path; do
      [ "${path:0:1}" = '~' ] && echo "$HOME${path:1}" || echo "$path"
   done <<< "$raw_paths"

   return 0
}

# Prints the regular expression pattern associated with a given identifier.
# All patterns are taken from a given file defaulting to <lookup file: regular expressions>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <regular expression file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <regular expression file> does not contain <identifier>'s identifier-string
alias regex_for_="_regex_for_ '$dot/../../Lookup Files/regular-expressions' "
function _regex_for_ {
   # The string used to search the lookup file for a certain pattern.
   local regex_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      server-header)             regex_identifier='Server declaration header:'            ;;
      server-body)               regex_identifier='Server declaration body:'              ;;
      trait-candidate)           regex_identifier='Trait declaration candidate:'          ;;
      trait)                     regex_identifier='Trait declaration:'                    ;;
      trait-configuration-entry) regex_identifier='Configuration entry:'                  ;;
      app-directory-tag)         regex_identifier='Application directory tag:'            ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$2\"" >&2
         return 1 ;;
   esac

   # Prints the lines following the search string in the lookup file, or returns on failure if that
   # operation fails.
   _lines_after_unique_ "$regex_identifier" "$1" || return 2

   return 0
}
