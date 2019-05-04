#!/bin/bash

# This script serves as a library of functions for working with the catalagoue's files
# (in Catalogue/Data). It can be "imported" via sourcing.
# It should be noted that this script activates alias expansion.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$CATALOGUE_SH" ] && readonly CATALOGUE_SH=true || return

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Gets the directory of this script.
dot_catalogue=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot_catalogue/scripting.sh"
. "$dot_catalogue/lookup.sh"


#-Functions-------------------------------------#


# Returns all of the fields in the column for a given attribute, from a given file type or list of
# entries.
#
# Arguments:
# * <attribute>
# * <in flag> possible values: "--in"
# * <data file identifier> possible values: "static-index", "runtime-index", "rack-index"
# or
# * <attribute>
# * <in flag> possible values: "--in"
# * <data file identifier> possible values: "static-config", "runtime-config", "rack-manifest"
# * <data file path>
# or
# * <attribute>
# * <in flag> possible values: "--in"
# * <data file identifier> possible values: *all of the above*
# * <entries flag> possible values: "--entries"
# * <data file entries>
#
# Return status:
# 0: success
# 1: <attribute>, a given flag or identifier was invalid
# 2: internal error
function data_for_ {
   # Makes sure the <in flag> was passed.
   [ "$2" = '--in' ] || { print_error_for --flag "$2"; return 1; }

   # Gets the column number for the given attribute in the given data file.
   local column; column=$(column_for_ "$1" --in "$3") || return $?

   # Returns the data from the column differently, depending on the different call signatures for
   # this function.
   case "$4" in
      # Call signature 3.
      --entries)
         # Prints the column of the given attribute in the given entries.
         cut -d : -f "$column" <<< "$5" ;;

      # Call signature 1 and 2.
      *)
         # Gets the data file differently depending on the call signature.
         local data_file
         if [ -z "$4" ]; then
            # Gets the file associated with the given data file identifier.
            data_file="$dot_catalogue/../$(path_for_ "$3")" || return 1
         else
            data_file=$4
         fi

         # Prints the column of the given attribute in the obtained data file.
         cut -d : -f "$column" "$data_file" ;;
   esac

   return 0
}

# Prints the entries in a data file of given type, containing a given sting value for a given
# attribute.
#
# Arguments:
# * <attribute>
# * <string value>
# * <in flag> possible values: "--in"
# * <data file identifier> possible values: "static-index", "runtime-index", "rack-index"
# or
# * <attribute>
# * <string value>
# * <in flag> possible values: "--in"
# * <data file identifier> possible values: "static-config", "runtime-config", "rack-manifest"
# * <data file>
#
# Return status:
# 0: success
# 1: <attribute>, a given flag or identifier was invalid
# 2: internal error
function entries_for_ {
   # Makes sure the <in flag> was passed.
   [ "$3" = '--in' ] || { print_error_for --flag "$3" ; return 1; }

   # Gets the column number for the given attribute in the given data file.
   local attribute_data; attribute_data=$(data_for_ "$1" --in "$4" "$5") || return $?

   # Gets the line numbers of the rows matching the <string value> in the attribute's data.
   local -r line_numbers=$(line_numbers_of_string_ "$2" --in-string "$attribute_data")

   # Returns early if there are no lines matching.
   [ -z "$line_numbers" ] && return 0

   # Gets the data file, if necessary.
   [ -z "$5" ] && local -r data_file="$dot_catalogue/../$(path_for_ "$4")" || local -r data_file=$5

   # Prints the entries in the data file at the determined line numbers.
   while read line_number; do
      echo "$(line_ "$line_number" --in-file "$data_file")"
   done <<< "$line_numbers"

   return 0
}

# Prints the fields for a given attribute in a given data file, thata are on the same row as a given
# string value for another attribute.
#
# Arguments:
# * <target attribute>
# * <with flag> possible values: "--with"
# * <source attribute>
# * <source field>
# * <in flag> possible values: "--in"
# * <data file identifier> possible values: "static-index", "runtime-index", "rack-index"
# or
# * <target attribute>
# * <with flag> possible values: "--with"
# * <source attribute>
# * <source field>
# * <in flag> possible values: "--in"
# * <data file identifier> possible values: "static-config", "runtime-config", "rack-manifest"
# * <data file>
#
# Return status:
# 0: success
# 1: <attribute>, a given flag or identifier was invalid
# 2: internal error
function fields_for_ {
   # Makes sure the <with flag> and <in flag> were passed.
   [ "$2" != '--with' ] && { print_error_for --flag "$2" ; return 1; }
   [ "$5" != '--in' ]   && { print_error_for --flag "$4" ; return 1; }

   # Gets the entries in the data file corresponding to where the <source field> is located in its
   # attribute column.
   local entries; entries=$(entries_for_ "$3" "$4" --in "$6" "$7") || return $?

   # Prints the target attribute's data from the previously obtained entries.
   data_for_ "$1" --in "$6" --entries "$entries"

   return 0
}
