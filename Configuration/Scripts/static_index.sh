#!/bin/bash

# This script scans the files in the Lightshow program directory as specified by <lookup file: file
# paths>, and prints out the static index generated from those files.
#
# A static index has the form:
# <server 1 identifier>:<server 1 class name>:<server 1 config-file path>:<server 1 file path>
# <server 2 identifier>:<server 2 class name>:<server 2 config-file path>:<server 2 file path>
# ...
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: a file contains multiple server declarations
# 3: a file contains a malformed server-declaration body


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting and lookup utilities.
. "$dot/../../Utilities/scripting.sh"
. "$dot/../../Utilities/lookup.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly lightshow_program_directory="$dot/../../$(path_for_ lightshow-directory)"
   readonly static_configuration_directory="$dot/../../$(path_for_ static-configuration-directory)"

   return 0
}


#-Functions-------------------------------------#


# Prints the server-declaration header and body contained in a given file. If none or more than one # are contained, a return on failure occurs.
#
# Arguments:
# * <search file>
#
# Returns:
# 0: success
# 1: <search file> contains no server-declaration
# 2: <search file> contains more than one server-declaration
function server_declaration_in_file_ {
   local -r header_pattern=$(regex_for_ server-header)
   local -r declaration=$(egrep -A1 "$header_pattern" "$1")

   # Asserts that there is exaclty one server declaration (which consists of 2 lines).
   [ $(wc -l <<< "$declaration") -lt 2 ] && return 1
   [ $(wc -l <<< "$declaration") -gt 2 ] && return 2

   echo "$declaration"
   return 0
}

# Prints a (partial) index entry for each given file. If the file does not contain a server-
# declaration, no entry is printed.
#
# Arguments:
# * <file>
#
# Return status:
# 0: success
# 1: <file> contains multiple server declarations
# 2: <file> contains a malformed server-declaration body
function index_entry_for_file_ {
   # Gets the server declaration contained in the file.
   server_declaration=$(server_declaration_in_file_ "$1"); return_status=$?

   # Returns successfully if there was no server declaration in the file, or on failure if there
   # were multiple.
   [ $return_status -eq 1 ] && return 0
   if [ $return_status -eq 2 ]; then
      echo "Error: \`$1\` contains multiple server declarations" >&2
      return 1
   fi

   # Asserts the validity of the declaration body.
   local -r body=$(line_at_number_ 2 --in-string "$server_declaration")
   local -r body_pattern=$(line_at_number_ 2 --in-string "$server_declaration")
   if ! egrep -q "$body_pattern" <<< "$body"; then
      echo "Error: \`$1\` contains a malformed server-declaration body" >&2
      return 2
   fi

   # Extracts the server identifier.
   local -r header=$(line_at_number_ 1 --in-string "$server_declaration")
   local -r server_identifier=$(cut -d '"' -f 2 <<< "$header")

   # Extracts the server class name.
   local -r class_pattern='class\s+[a-zA-Z_][a-zA-Z0-9_]*'
   local -r class_definition=$(egrep -o "$class_pattern" <<< "$body")
   local -r class_name=$(tr -s ' ' <<< "$class_definition" | cut -d ' ' -f 2)

   # Prints the result and returns on success.
   echo "$server_identifier:$class_name:$1"
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Iterates over the files in the Lightshow program directory.
server_counter=0
for file in $(ls "$lightshow_program_directory"); do
   # Gets the index entry corresponding to the given file, without the static configuration file
   # path.
   partial_entry=$(index_entry_for_file_ "$lightshow_program_directory/$file") || exit $(($?+1))


   # Only prints the entry and increments the server counter if there actually was a server in the
   # file.
   if [ -n "$partial_entry" ]; then
      entry="$partial_entry:$static_configuration_directory/$server_counter"
      echo "$entry"
      ((server_counter++))
   fi
done

exit 0
