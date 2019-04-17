#!/bin/bash

# This script scans given program files for a given server-identifier-declaration. It outputs a
# trait-value map from the trait-declarations contained in the associated server.
#
# A trait-value map consists of entries of the form:
# <trait ID 1>: <value 1>
# <trait ID 2>: <value 2>
# ...
# where all trait-identifiers are unique.
#
# A trait-declaration consists of a header and a body, as specified by <lookup file: regular
# expressions>.
#
# Arguments:
# * <server type/identifier>
# * <program files> optional, for testing purposes
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: none of the <program files> contains the server for <server type/identifier>
# 3: <server type/identifier>'s server is missing a trait-declarations-end tag
# 4: <server type/identifier>'s server contains duplicate trait-identifiers
# 5: <server type/identifier>'s server malformed trait-declaration bodies


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
   # Binds the server identifier.
   readonly server_identifier=$1

   # Sets the location of the <program files> as the remaining command line arguments, or to the
   # files in the lightshow program folder as specified by <lookup file: file locations> if none
   # were passed.
   shift
   if [ -n "$1" ]; then
      readonly program_files=$@
   else
      readonly program_files=$(ls "$dot/../../$(path_for_ lightshow-directory)")
   fi
}


#-Functions-------------------------------------#


# Prints a line numbered list of trait-declaration components corresponding to a given identifier
# within a given file. If the file contains a trait declarations end tag, as specified by <lookup
# file: regular expressions>, the search is only performed upto the line of the tag.
#
# Arguments:
# * <component identifier>, possible values: "header-candidate", "header", "body"
# * <file>
#
# Return status:
# 0: success
# 1: the given <component identifier> is invalid
function line_numbered_declaration_component_ {
   # Sets the regex pattern associated with the given identifier and a flag indicating whether
   # it was "body", or prints an error and returns on failure if the identifier was invalid.
   case "$1" in
      header-candidate|header)
         local -r component_pattern=$(regex_for_ "trait-$1")
         local -r identifier_was_body=false
         ;;
      body)
         # A declaration body is identified by searching for a header, so the pattern is set as
         # such.
         local -r component_pattern=$(regex_for_ trait-header)
         local -r identifier_was_body=true
         ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$1\"" >&2
         return 1 ;;
   esac

   # Sets a flag needed in the loop below in the case that identifier_was_body.
   local previous_line_matched=false
   # Starts counting lines with a value of `1`.
   local line_counter=1
   # Saves the regex for the trait declarations end tag, as it will be referenced repeatedly.
   local -r end_tag_regex=$(regex_for_ traits-end-tag)

   # Iterates over the lines in <file>.
   while read -r line; do
      # Checks for the end tag first unconditionally, and breaks if it was read.
      egrep -q "$end_tag_regex" <<< "$line" && break

      # This can only trigger in the case where identifier_was_body.
      # Prints the current line if the previous one matched, and unsets the associated flag.
      if $identifier_was_body && $previous_line_matched; then
         echo "$line_counter:$line"
         previous_line_matched=false

      # This can only trigger if not identifier_was_body, or the previous line did not match.
      # Checks for lines matching the pattern established above.
      elif egrep -q "$component_pattern" <<< "$line"; then
         # Prints the line or sets the previous line matched flag, depending on whether
         # identifier_was_body.
         $identifier_was_body && previous_line_matched=true || echo "$line_counter:$line"
      fi

      # Increments the line counter unconditionally.
      ((line_counter++))
   done < "$2"

   return 0
}

# Prints a warning for each malformed declaration header, given lists of header candidates and
# valid headers.
#
# Arguments:
# * <list of line numbered declaration header candidates>
# * <list of line numbered declaration headers>
function warn_about_malformed_headers {
   # Gets the diff between the lists of header candidates and valid headers (which `comm` expects to
   # be lexically sorted).
   local -r malformed_headers=$(comm -23 <(sort <<< "$1") <(sort <<< "$2"))

   # Returns early if no malformed headers were found.
   [ -z "$malformed_headers" ] && return 0

   # Prints a warning message for each malformed line.
   while read -r malformed_line; do
      # Gets the line number of the malformed line.
      local line_number=$(cut -d : -f 1 <<< "$malformed_line")

      echo "Warning: \`$program_file\`: $line_number: malformed trait-declaration header" >&2
   done <<< "$malformed_headers"

   return 0
}


# Prints an error message and returns on failure for every duplicate trait-identifier in a given
# list.
#
# Arguments:
# * <list of line numbered trait-identifiers>
#
# Return status:
# 0: success
# 1: <list of line numbered trait-identifiers> contains duplicates
function assert_trait_identifier_uniqueness_ {
   # Gets a list of duplicate identifiers.
   local -r duplicate_identifiers=$(cut -d : -f 2 <<< "$1" | sort | uniq -d)

   # Returns successfully if no duplicates were found.
   [ -z "$duplicate_identifiers" ] && return 0

   # Prints and error message for each duplicate.
   while read duplicate; do
      # Gets the lines of the duplicates in a comma-seperated list.
      local -r duplicate_lines=$(egrep "^\s*[0-9]\s*:\s*$duplicate\s*\$" <<< "$1")
      local -r line_number_list=$(cut -d : -f 1 <<< "$duplicate_lines" | paste -s -d , -)

      echo "Error: \`$program_file\`: $line_number_list: duplicate trait-identifiers" >&2
   done <<< "$duplicate_identifiers"

   return 1
}

# Prints an error message and returns on failure for every malformed declaration-body in a given
# list.
#
# Arguments:
# * <list of line numbered declaration bodies>
#
# Return status:
# 0: success
# 1: <list of line numbered declaration bodies> contains a malformed body
function assert_declaration_body_validity_ {
   # Gets the lines containing malformed trait-declaration bodies.
   local -r line_numbered_body_pattern="^\s*[0-9]+\s*:$(regex_for_ trait-body | sed -e 's/^\^//')"
   local -r malformed_bodies=$(egrep -v "$line_numbered_body_pattern" <<< "$1")

   # Returns successfully if there are no malformed bodies.
   [ -z "$malformed_bodies" ] && return 0

   # Prints an error message for each malformed body.
   while read -r malformed_body; do
      # Gets the line number of the malformed body.
      local -r line_number=$(cut -d : -f 1 <<< "$malformed_body")

      echo "Error: \`$program_file\`: $line_number: malformed trait-declaration body" >&2
   done <<< "$malformed_bodies"

   return 1
}

# Prints the list of trait-identifiers contained in the trait-declaration headers of a given file.
# Warnings are printed to stderr for any lines containing header-candidates that are not valid
# headers, as specified by <lookup file: regular expressions>.
#
# Arguments:
# * <file>
#
# Return status:
# 0: success
# 1: <file> contains duplicate trait-identifiers
function trait_identifiers_in_ {
   # Gets a line numbered list of the possibly malformed trait-declaration headers in <file>.
   local -r line_numbered_header_candidates=$(
      line_numbered_declaration_component_ header-candidate "$1"
   )
   # Gets a line numbered list of the valid trait-declaration headers in <file>.
   local -r line_numbered_headers=$(line_numbered_declaration_component_ header "$1")

   warn_about_malformed_headers "$line_numbered_header_candidates" "$line_numbered_headers"

   # Gets the lines in which the valid declaration headers are located.
   local -r header_line_numbers=$(cut -d : -f 1 <<< "$line_numbered_headers")
   # Gets the valid trait-declaration headers' identifiers.
   local -r trait_identifiers=$(cut -d '"' -f 2 <<< "$line_numbered_headers")
   # Creates a line numbered list of trait-identifiers.
   local -r line_numbered_trait_identifiers=$(
      paste -d : <(echo "$header_line_numbers") <(echo "$trait_identifiers")
   )

   # Makes sure there are no two same trait-identifiers, or returns on failure.
   assert_trait_identifier_uniqueness_ "$line_numbered_trait_identifiers" || return 1

   echo "$trait_identifiers"
   return 0
}

# Prints the list of trait-values contained in the trait-declaration bodies of a given file.
#
# Arguments:
# * <file>
#
# Return status:
# 0: success
# 1: <file> contains malform trait-declaration bodies
function trait_values_in_ {
   # Gets the lines right after the declaration headers in <file>, containing (possibly malformed)
   # declaration bodies.
   local -r declaration_bodies=$(line_numbered_declaration_component_ body "$1")

   # Makes sure the declaration bodies are all valid, or returns on failure.
   assert_declaration_body_validity_ "$declaration_bodies" || return 1

   # Gets the declaration bodys' values.
   local -r declaration_body_values=$(cut -d '=' -f 2 <<< "$declaration_bodies" | egrep -o '[0-9]+')

   echo "$declaration_body_values"
   return 0
}

# Scans the $program_files for the one declaring the server with $server_identifier. If one is
# found, the file is printed. Otherwise a return on failure occurs.
#
# 0: success
# 1: no file containing
function file_declaring_server_type_ {
   # Iterates over the program files.
   for file in $program_files; do
      # Gets all of the lines after server-identifier-declaration headers.
      pattern=$(regex_for_ server-identifier-header)
      identifier_bodies=$(egrep -A1 "$pattern" "$file" | egrep -v "$pattern")

      # Returns successfully if one the bodies contains "$server_identifier".
      if egrep -q "\"$server_identifier\"" <<< "$identifier_bodies"; then
         echo "$file"
         return 0
      fi
   done

   # Returns on failure if no successful return occurred before.
   return 1
}

# TODO: Implement.
# >> Get the line number of the server identifier declaration. = A
# >> Get the line numbers of all of the server-declarations.
# >> Get the line number that is closest to and smaller than A. = B
# >> Get the line number that is closest to and bigger than A. = C
# >> Get the line numbers of all of the server-declarations.
# >> Get the line number that is closest to and bigger than B. = D
# >> If D > C, the trait decls end tag is missing for the server.
# >> Otherwise the search space is B...D
function trait_search_space_for_file_ {


}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 1 '<program file: optional>' || exit 1
declare_constants "$@"

matching_file=$(file_declaring_server_type_) || exit 2

trait_search_space=$(trait_search_space_for_file_ "$matching_file") || exit 3

# TODO: Have the functions below use the trait search space.

# Gets the lists of trait-identifiers contained in $matching_file's trait-declarations. If any
# trait-declaration headers have the same identifier, an error is printed and a return on failure
# occurs.
trait_identifiers=$(trait_identifiers_in_ "$matching_file") || exit 4

# Returns early if no declarations and therefore no trait-identifiers were found.
[ -n "$trait_identifiers" ] || exit 0

# Gets the list of trait-values contained in $matching_file's trait-declarations in the same order
# as the trait-identifiers. If any trait-declaration bodies are malformed, an error is printed and a
# return on failure occurs.
trait_values=$(trait_values_in_ "$matching_file") || exit 5

# Merges the trait configuration items into joined lines.
readonly configuration=$(paste -d ':' <(echo "$trait_identifiers") <(echo "$trait_values"))

# Prints the (formatted) trait-value map generated from the $matching_file.
sed -e 's/:/: /' <<< "$configuration"
exit 0
