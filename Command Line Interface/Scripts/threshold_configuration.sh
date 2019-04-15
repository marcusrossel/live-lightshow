#!/bin/bash

# This script prints the configuration corresponding to the threshold-declarations in a given
# `.ino`-file.
#
# A "threshold-declaration" has consists of a header and a body, as specified by <utility file:
# regular expressions>.
# The printed configuration consists of a sequence of configuration entries, as specified by
# <utility file: regular expressions>, where now two entries have the same microphone-identifier.
#
# Arguments:
# * <.ino file> optional, for testing purposes
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: <.ino file> is not readable or has the wrong file type
# 3: <.ino file> contains duplicate microphone identifiers
# 4: <.ino file> contains malformed threshold-declaration bodies


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports CLI utilities.
. "$_dot/../Libraries/utilities.sh"
. "$_dot/../Libraries/constants.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   # Sets the location of the <.ino file> as the first command line argument, or to the one
   # specified by <utility file: file locations> if none was passed.
   if [ -n "$1" ]; then
      readonly ino_file=$1
   else
      local -r program_folder="$dot/../../`location_of_ --repo-program-directory`"
      readonly ino_file="$program_folder/`ls -1 "$program_folder" | egrep '\.ino$'`"
   fi
}


#-Functions-------------------------------------#


# Prints a line numbered list of threshold-declaration components corresponding to a given flag
# within a given file. If the file contains a "threshold declarations end"-tag, as specified by
# <utility file: regular expressions>, the search is only performed upto the line of the tag.
#
# Arguments:
# * <component flag>, possible values: "--header-candidate", "--header", "--body"
# * <file>
#
# Return status:
# 0: success
# 1: the given <flag> is invalid
function line_numbered_declaration_component_ {
   # Sets the regex pattern associated with a given flag and a flag indicating whether <flag> was
   # "--body", or prints an error and returns on failure if the given flag was invalid.
   case "$1" in
      --header-candidate|--header)
         local -r component_pattern=`regex_for_ "$1"`
         local -r flag_was_for_body=false
         ;;
      --body)
         # A declaration body is identifier by searching for a header, so the pattern is set as
         # such.
         local -r component_pattern=`regex_for_ --header`
         local -r flag_was_for_body=true
         ;;
      *)
         echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$1\"" >&2
         return 1 ;;
   esac

   # Sets a flag needed in the loop below in the case that <flag> was "--body".
   local previous_line_matched=false
   # Starts counting lines with a value of `1`.
   local line_counter=1
   # Saves the regex for the "threshold declarations end"-tag, as it will be reference repeatedly.
   local -r end_tag_regex=`regex_for_ --end-tag`

   # Iterates over the line in <file>.
   while read -r line; do
      # Checks for the end tag first unconditionally, and breaks if it was read.
      egrep -q "$end_tag_regex" <<< "$line" && break

      # This can only trigger in the case where <flag> was "--body".
      # Prints the current line if the previous one matched, and unsets the associated flag.
      if $flag_was_for_body && $previous_line_matched; then
         echo "$line_counter:$line"
         previous_line_matched=false

      # This can only trigger if <flag> was not "--body" or the previous line did not match.
      # Checks for lines matching the pattern established above.
      elif egrep -q "$component_pattern" <<< "$line"; then
         # Prints the line or sets the "previous line matched"-flag, depending on whether the
         # <flag> was "--body".
         $flag_was_for_body && previous_line_matched=true || echo "$line_counter:$line"
      fi

      # Increments the line counter unconditionally.
      (( line_counter++ ))
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
   local -r malformed_headers=`comm -23 <(sort <<< "$1") <(sort <<< "$2")`

   # Returns early if no malformed headers were found.
   [ -z "$malformed_headers" ] && return 0

   # Prints a warning message for each malformed line.
   while read -r malformed_line; do
      # Gets the line number of the malformed line.
      local line_number=`cut -d : -f 1 <<< "$malformed_line"`

      echo "Warning: \`$ino_file\` line $line_number: malformed threshold-declaration header" >&2
   done <<< "$malformed_headers"

   return 0
}


# Prints an error message and returns on failure for every duplicate microphone-identifier in a
# given list.
#
# Arguments:
# * <list of line numbered microphone-identifiers>
#
# Return status:
# 0: success
# 1: <list of line numbered microphone-identifiers> contains duplicates
function assert_microphone_identifier_uniqueness_ {
   # Gets a list of duplicate identifiers.
   local -r duplicate_identifiers=`cut -d : -f 2 <<< "$1" | sort | uniq -d`

   # Returns successfully if no duplicates were found.
   [ -z "$duplicate_identifiers" ] && return 0

   # Prints and error message for each duplicate.
   while read duplicate; do
      # Gets the lines of the duplicates in a comma-seperated list.
      local -r duplicate_lines=`egrep "^\s*[0-9]\s*:\s*$duplicate\s*\$" <<< "$1"`
      local -r line_number_list=`cut -d : -f 1 <<< "$duplicate_lines" | paste -s -d , -`

      echo "Error: \`$ino_file\` lines $line_number_list: duplicate microphone-identifiers" >&2
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
   # Gets the lines containing malformed threshold-declaration bodies.
   local -r line_numbered_body_pattern="^\s*[0-9]+\s*:`regex_for_ --body | sed -e 's/^\^//'`"
   local -r malformed_bodies=`egrep -v "$line_numbered_body_pattern" <<< "$1"`

   # Returns successfully if there are no malformed bodies.
   [ -z "$malformed_bodies" ] && return 0

   # Prints an error message for each malformed body.
   while read -r malformed_body; do
      # Gets the line number of the malformed body.
      local -r line_number=`cut -d : -f 1 <<< "$malformed_body"`

      echo "Error: \`$ino_file\` line $line_number: malformed threshold-declaration body" >&2
   done <<< "$malformed_bodies"

   return 1
}

# Prints the list of microphone-identifiers contained in the threshold-declaration headers of a
# given file. Warnings are printed to stderr for any lines containing header-candidates that are not
# valid headers, as specified by <utility file: regular expressions>.
#
# Arguments:
# * <file>
#
# Return status:
# 0: success
# 1: <file> contains duplicate microphone-identifiers
function microphone_identifiers_in_ {
   # Gets a line numbered list of the possibly malformed threshold-declaration headers in <file>.
   local -r line_numbered_header_candidates=`
      line_numbered_declaration_component_ --header-candidate "$1"
   `
   # Gets a line numbered list of the valid threshold-declaration headers in <file>.
   local -r line_numbered_headers=`line_numbered_declaration_component_ --header "$1"`

   warn_about_malformed_headers "$line_numbered_header_candidates" "$line_numbered_headers"

   # Gets the lines in which the valid declaration headers are located.
   local -r header_line_numbers=`cut -d : -f 1 <<< "$line_numbered_headers"`
   # Gets the valid threshold-declaration headers' microphone-identifiers.
   local -r microphone_identifiers=`cut -d '"' -f 2 <<< "$line_numbered_headers"`
   # Creates a line numbered list of microphone-identifiers.
   local -r line_numbered_microphone_identifiers=`
      paste -d : <(echo "$header_line_numbers") <(echo "$microphone_identifiers")
   `

   # Makes sure there are no two same microphone identifiers, or returns on failure.
   assert_microphone_identifier_uniqueness_ "$line_numbered_microphone_identifiers" || return 1

   echo "$microphone_identifiers"
   return 0
}

# Prints the list of threshold-values contained in the threshold-declaration bodies of a given file.
# given file.
#
# Arguments:
# * <file>
#
# Return status:
# 0: success
# 1: <file> contains malform threshold-declaration bodies
function threshold_values_in_ {
   # Gets the lines right after the declaration headers in <file>, containing (possibly malformed)
   # declaration bodies.
   local -r declaration_bodies=`line_numbered_declaration_component_ --body "$1"`

   # Makes sure the declaration bodies are all valid, or returns on failure.
   assert_declaration_body_validity_ "$declaration_bodies" || return 1

   # Gets the declaration bodys' values.
   local -r declaration_body_values=`cut -d '=' -f 2 <<< "$declaration_bodies" | egrep -o '[0-9]+'`

   echo "$declaration_body_values"
   return 0
}


#-Main------------------------------------------#

assert_correct_argument_count_ 0 1 '<.ino file: optional>' || exit 1 #RS=1
declare_constants "$@"

# Makes sure the given file is valid, or returns on failure.
assert_path_validity_ "$ino_file" --ino || exit 2 #RS=2

# Gets the lists of microphone-identifiers contained in <.ino file>'s threshold-declarations. If any
# threshold-declaration headers have the same microphone-identifier, an error is printed and a
# return on failure occurs.
microphone_identifiers=`microphone_identifiers_in_ "$ino_file"` || exit 3 #RS=3

# Returns early if no declarations and therefore no microphone-identifiers were found.
[ -n "$microphone_identifiers" ] || exit 0

# Gets the list of threshold-values contained in <.ino file>'s threshold-declarations in the same
# order as the microphone-identifiers. If any threshold-declaration bodies are malformed, an error
# is printed and a return on failure occurs.
threshold_values=`threshold_values_in_ "$ino_file"` || exit 4 #RS=4

# Merges the threshold configuration items into joined lines.
readonly threshold_configuration=`
   paste -d ':' <(echo "$microphone_identifiers") <(echo "$threshold_values")
`

# Prints the (formatted) threshold-configuration generated from the <.ino file>.
sed -e 's/:/: /' <<< "$threshold_configuration"
exit 0
