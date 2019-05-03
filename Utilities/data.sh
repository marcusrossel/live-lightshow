#!/bin/bash

# This script serves as a library of functions for conveniently accessing this project's data files
# (in Catalogue/Data). It can be "imported" via sourcing.
# It should be noted that this script activates alias expansion.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$DATA_SH" ] && readonly DATA_SH=true || return

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Gets the directory of this script.
dot_data=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot_data/scripting.sh"
. "$dot_data/lookup.sh"


#-Functions-------------------------------------#


# Returns all of the values in the column for a given attribute, of a given index type, from a given
# file of list of index entries.
#
# Arguments:
# * <attribute identifier>
# * <in flag> possible values: "--in"
# * <index identifier> possible values: "static-index", "runtime-index"
# or
# * <attribute identifier>
# * <in-entries flag> possible values: "--in-entries"
# * <entries>
# * <of flag> possible values: "--of"
# * <index identifier> possible values: "static-index", "runtime-index"
#
# Return status:
# 0: success
# 1: a given flag or identifier was invalid
# TODO: This now collides with lookup.sh::column_for_
function column_for_ {
   # Prints the target column of the given index file type / entries.
   case "$2" in
      --in)
         # Gets the index file associated with the given index identifier.
         index_file="$dot_data/../$(path_for_ "$3")" || return 1
         # Binds the target column.
         target_column=$(_column_number_for_ "$1" --in "$3") || return 1
         # Prints the column of the given attribute in the obtained index file.
         cut -d : -f "$target_column" "$index_file" ;;

      --in-entries)
         # Makes sure the <of flag> was passed.
         [ "$4" != '--of' ] && { print_error_for --flag "$4" ; return 1; }

         # Binds the target column.
         target_column=$(_column_number_for_ "$1" --in "$5") || return 1
         # Prints the column of the given attribute in the given entries.
         cut -d : -f "$target_column" <<< "$3" ;;

      *) print_error_for --flag "$2" ; return 1 ;;
   esac

   return 0
}

# Prints the entries in an index of given type, containing a given sting value for a given
# attribute.
# All entries are taken from the index files specified by <lookup file: file paths>.
#
# Arguments:
# * <attribute identifier> possible values: "server-id", "class-name", "config-file", "file-path"
# * <string value>
# * <in flag> possible values: "--in"
# * <index identifier> possible values: "static-index", "runtime-index"
#
# Return status:
# 0: success
# 1: <attribute identifier>, <index identifier> or <in flag> was invalid
# 2: <string value> is not an existing value for the attribute in the index file
function index_entries_for_ {
   # Makes sure the <in flag> was passed.
   [ "$3" != '--in' ] && { print_error_for --flag "$3" ; return 1; }

   # Gets the column of the attribute in the index file.
   column=$(column_for_ "$1" --in "$4") || return 1

   # Gets the line numbers of the rows matching the <string value> in the column, or returns on
   # failure if none were found.
   local -r line_numbers=$(line_numbers_of_string_ "$2" --in-string "$column")
   [ -z "$line_numbers" ] && return 2

   # Gets the index file.
   local -r index_file="$dot_data/../$(path_for_ "$4")"

   # Prints the entries in the index at the determined line numbers.
   while read line_number; do
      echo "$(line_ "$line_number" --in-file "$index_file")"
   done <<< "$line_numbers"

   return 0
}

# Prints the field for a given attribute in a given index, that's on the same row as a given
# string value for another attribute.
# All entries are taken from the index files specified by <lookup file: file paths>.
#
# Arguments:
# * <target attribute> possible values: "server-id", "class-name", "config-file", "file-path"
# * <in flag> possible values: "--in"
# * <index identifier> possible values: "static-index", "runtime-index"
# * <with flag> possible values: "--with"
# * <source attribute> possible values: "server-id", "class-name", "config-file", "file-path"
# * <source field>
#
# Return status:
# 0: success
# 1: <target attribute>, <source attribute>, <in-entries-of flag>, <index-identifier>, or
#    <with flag> was invalid
# 2: <source field> is not an existing value for the attribute in the index file
function values_for_ {
   # Makes sure the <in flag> and <with flag> were passed.
   [ "$2" != '--in' ]   && { print_error_for --flag "$2" ; return 1; }
   [ "$4" != '--with' ] && { print_error_for --flag "$4" ; return 1; }

   # Gets the entries in the index corresponding to where the <source field> is located in its
   # attribute column, or returns on error if none was found.
   index_entries=$(index_entries_for_ "$5" "$6" --in "$3") || return 2

   # Prints the target column of the previously obtained index entries.
   column_for_ "$1" --in-entries "$index_entries" --of "$3"

   return 0
}
