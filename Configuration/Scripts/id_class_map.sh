#!/bin/bash

# This script scans given program files, determining which class with the "#server" tag has which
# unique identifier tagged with "#server-identifier". It prints a result in the form:
# <server 1 ID>: <server 1 class name>
# <server 2 ID>: <server 2 class name>
# ...
#
# A server-declaration consists of one line containing the #server tag (followed only by whitespace)
# with the following line containing a class definition.
#
# A server-declaration consists of one line containing the #server-identifier tag (followed only by
# whitespace) with the following line containing a String-declaration with a string-literal.
#
# Arguments:
# * <program files> optional, for testing purposes
#
# Return status:
# 0: success
# 1: invalid number of arguments
# 2: a program contained a malformed server-identifier-declaration body
# 3: a program contained a malformed server-declaration body
# 4: a program contained unequal numbers of server- and server-identifier-declarations
# 5: a server-identifier occurred multiple times


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports lookup and utilities.
. "$_dot/../Utilities/lookup.sh"
. "$_dot/../Utilities/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   # Sets the location of the <program files> as the command line arguments, or to the files in the
   # lightshow program folder as specified by <lookup file: file locations> if none were passed.
   if [ -n "$1" ]; then
      readonly program_files=$@
   else
      readonly program_files=$(ls "$dot/../../$(path_for_ lightshow-directory)")
   fi
}


#-Functions-------------------------------------#


# Prints a line numbered list of server(-identifier)-declaration components corresponding to a
# given identifier within a given file.

# Arguments:
# * <component identifier>, possible values: "server-body", "server-identifier-body"
# * <file>
#
# Return status:
# 0: success
# 1: the given <component identifier> is invalid
function line_numbered_declaration_component_ {
   # Sets the regex pattern associated with the given identifier, or prints an error and returns on
   # failure if the identifier was invalid.
   case "$1" in
      server-body)            local -r component_pattern=$(regex_for_ server-header) ;;
      server-identifier-body) local -r component_pattern=$(regex_for_ server-identifier-header) ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$1\"" >&2
         return 1 ;;
   esac

   # Sets a flag needed in the loop below.
   local previous_line_matched=false
   # Starts counting lines with a value of `1`.
   local line_counter=1

   # Iterates over the lines in <file>.
   while read -r line; do
      # Prints the current line if the previous one matched, and unsets the associated flag.
      if $previous_line_matched; then
         echo "$line_counter:$line"
         previous_line_matched=false

      # Checks for lines matching the pattern established above.
      elif egrep -q "$component_pattern" <<< "$line"; then
         previous_line_matched=true
      fi

      # Increments the line counter unconditionally.
      ((line_counter++))
   done < "$2"

   return 0
}

# Prints an error message and returns on failure for every malformed declaration-body in a given
# list.
#
# Arguments:
# * <declaration identifier>, possible values: "server", "server-identifier"
# * <list of line numbered declaration bodies>
#
# Return status:
# 0: success
# 1: <declaration identifier> is invalid
# 2: <list of line numbered declaration bodies> contains a malformed body
# 3: internal error
function assert_body_validity_for_ {
   # Sets the regex-pattern associated with the given <declaration identifier>, or prints an error
   # and returns on failure if it was invalid.
   case "$1" in
      server|server-identifier) local -r body_pattern=$(regex_for_ $1-body) ;;
      *) echo "Error: \`${FUNCNAME[0]}\` received invald identifier \"$1\"" >&2
         return 1
   esac

   # Gets the lines containing malformed server-declaration bodies.
   local -r line_numbered_body_pattern="^\s*[0-9]+\s*:$(sed -e 's/^\^//' <<< "$body_pattern")"
   local -r malformed_bodies=$(egrep -v "$line_numbered_body_pattern" <<< "$2")

   # Returns successfully if there are no malformed bodies.
   [ -z "$malformed_bodies" ] && return 0

   # Prints an error message for each malformed body.
   while read -r malformed_body; do
      # Gets the line number of the malformed body.
      local -r line_number=$(cut -d : -f 1 <<< "$malformed_body")

      case "$1" in
         server)
            echo "Error: \`$program_file\`: $line_number: malformed server-declaration body" >&2 ;;
         server-identifier)
            echo "Error: \`$program_file\`: $line_number: malformed server-identifier-declaration" \
                 "body" >&2 ;;
         *) # Unreachable.
            echo "Error: \`${FUNCNAME[0]}\` reached unreachable code" >&2
            return 3 ;;
      esac
   done <<< "$malformed_bodies"

   return 1
}

# Prints the list of server class names contained in a given file.
#
# Arguments:
# * <file>
#
# Return status:
# 0: success
# 1: <file> contains malformed declaration bodies
function server_class_names_in_ {
   # Gets the lines right after the server declaration headers in <file>, containing (possibly
   # malformed) server declaration bodies.
   local -r server_bodies=$(line_numbered_declaration_component_ server-body "$1")

   # Makes sure the declaration bodies are all valid, or returns on failure.
   assert_body_validity_for_ server "$server_bodies" || return 1

   # Gets the class names.
   local -r class_pattern='class\s+[a-zA-Z_][a-zA-Z0-9_]*'
   local -r class_definitions=$(egrep -o "$class_pattern" <<< "$server_bodies")
   local -r class_names=$(tr -s ' ' <<< "$class_definitions" | cut -d ' ' -f 2)

   echo "$class_names"
   return 0
}

# Prints the list of server class names contained in a given file.
#
# Arguments:
# * <file>
#
# Return status:
# 0: success
# 1: <file> contains malformed declaration bodies
function server_identifiers_in_ {
   # Gets the lines right after the server identifier declaration headers in <file>, containing
   # (possibly malformed) server identifier declaration bodies.
   local -r declaration_bodies=$(line_numbered_declaration_component_ server-identifier-body "$1")

   # Makes sure the declaration bodies are all valid, or returns on failure.
   assert_body_validity_for_ server-identifier "$declaration_bodies" || return 1

   # Gets the server identifiers.
   local -r identifiers=$(cut -d '"' -f 2 <<< "$declaration_bodies")

   echo "$identifiers"
   return 0
}

# Prints a combined ID-class map for each of the given program files.
#
# Arguments:
# * <program files>
#
# Return status:
# 0: success
# 1: a program contained a malformed server-identifier-declaration body
# 2: a program contained a malformed server-declaration body
# 3: a program contained unequal numbers of server- and server-identifier-declarations
function combined_map_for_program_files_ {
   # Iterates over the give nprogram files.
   for program_file in $1; do
      # Gets the lists of server-identifiers contained in <program file>'s server-identifier
      # declarations. If any server-identifier-declaration bodies are malformed, or have the same
      # value, an error is printed and a return on failure occurs.
      server_identifiers=$(server_identifiers_in_ "$program_file") || return 1

      # Gets the list of server class names contained in <program file>'s server-declarations in the
      # same order as the server-identifiers. If any server-declaration bodies are malformed, an
      # error is printed and a return on failure occurs.
      server_class_names=$(server_class_names_in_ "$program_file") || return 2

      # Makes sure there is an equal number of server-identifiers and server class names, or else
      # prints and error and returns on failure.
      readonly id_count=$(wc -l <<< "$server_identifiers")
      readonly class_count=$(wc -l <<< "$server_class_names")
      if [ $id_count -gt $class_count ]; then
         echo "Error: \`$program_file\` contains more server-identifiers than server-classes" >&2
         return 3
      elif [ $id_count -lt $class_count ]; then
         echo "Error: \`$program_file\` contains more server-classes than server-identifiers" >&2
         return 3
      fi

      # Merges the results into joined lines.
      readonly result=$(paste -d ':' <(echo "$server_identifiers") <(echo "$server_class_names"))

      # Prints the (formatted) configuration generated from the program file as part of the
      # combined map.
      sed -e 's/:/: /' <<< "$result"
   done
}

# For a given ID-class map, prints an error message for each duplicate server-identifier and returns
# on failure.
#
# Arguments:
# * <ID-class map>
#
# Return status:
# 0: success
# 1: a server-identifier was not unique
function assert_identifier_uniqueness_ {
   # Gets the identifier from the given ID-class map.
   local -r identifiers=$(cut -d : -f 1 <<< "$1")
   # Sets up a return variable, to be set to 1 in the case of duplicate identifiers.
   local return_value=0

   # Iterates over a map of <count>: <identifier>.
   sort <<< "$identifiers" | uniq -c | while read count_identifier; do
      local count=$(tr -s ' ' <<< "$count_identifier" | cut -d ' ' -f 1)

      # Prints an error message and sets a failing return value if an identifier appeared more than
      # once.
      if [ "$count" -gt 1 ]; then
         local identifier=$(tr -s ' ' <<< "$count_identifier" | cut -d ' ' -f 2-)
         echo "Error: server-identifier \"$identifier\" is not unique" >&2

         return_value=1
      fi
   done

   return $return_value
}


#-Main------------------------------------------#


# TODO: Figure out a strategy for this (add an infinite upper bound to the function).
# assert_correct_argument_count_ 0 || exit 1

# Gets the combined ID-class map of all given files.
combined_map=$(combined_map_for_program_files_ $program_files) || exit $(($?+1))

# Makes sure there are no identifier collisions.
assert_identifier_uniqueness_ "$combined_map" || exit 5

# Prints the result.
echo "$combined_map"

exit 0
