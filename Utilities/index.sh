#!/bin/bash

# This script serves as a library of functions for conveniently accessing this project's index
# files. It can be "imported" via sourcing.
# It should be noted that this script activates alias expansion.

# TODO: Consolidate some of these functions with flags/identifiers.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$INDEX_SH" ] && readonly INDEX_SH=true || return

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Saves the previous value of the $dot-variable.
previous_dot="$dot"
# Gets the directory of this script.
dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting and lookup utilities.
. "$dot/scripting.sh"
. "$dot/lookup.sh"


#-Private-Functions-----------------------------#


# Prints the entries in a given index file containing a given string value for a given column.
#
# Arguments:
# * <index file>
# * <column>
# * <string value>
#
# Return status:
# 0: success
# 1: <string value> is not an existing value in <column> in <index file>
function _index_entries_in_file_for_column_matching_value_ {
   # Gets the column from the index file.
   local -r index_column=$(cut -d : -f "$2" "$1")

   # Gets the line numbers of the rows matching the <string value>, or returns on failure if none
   # were found.
   line_numbers=$(line_numbers_of_string_ "$3" --in-string "$index_column") || return 1

   # Prints the entries in the index corresponding to the row.
   while read line_number; do
      echo "$(line_ "$line_number" --in-file "$1")"
   done <<< "$line_numbers"

   return 0
}


#-Functions-------------------------------------#


# Prints the column number of a given attribute in a given index.
#
# Arguments:
# * <attribute identifier>
# ** possible values for <index identifier>="static index":
# *** "server-id", "class-name", "config-file", "file-path"
# ** possible values for <index identifier>="runtime index":
# *** "instance-id", "server-id", "config-file"
# * <in flag> possible values: "--in"
# * <index identifier> possible values: "static-index", "runtime-index"
#
# Return status:
# 0: success
# 1: the given attribute is not a valid attribute in the given index, <index identifier> is invalid
#    or <in flag> was missing
function column_number_for_ {
   # Makes sure the <in flag> was passed.
   if [ "$2" != '--in' ]; then
      echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$2\"" >&2
      return 1
   fi

   # Differentiates on the <index identifier>.
   case "$3" in
      # Handels static-index attributes.
      static-index)
         case "$1" in
            server-id)   echo 1 ;;
            class-name)  echo 2 ;;
            file-path)   echo 3 ;;
            config-file) echo 4 ;;
            *) echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$1\"" >&2
               return 1 ;;
         esac ;;

      # Handels runtime-index attributes.
      runtime-index)
         case "$1" in
            instance-id) echo 1 ;;
            server-id)   echo 2 ;;
            config-file) echo 3 ;;
            *) echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$1\"" >&2
               return 1 ;;
         esac ;;

      *) echo "Error: \`${FUNCNAME[0]}\` received invalid identifier \"$3\"" >&2
      return 1 ;;
   esac

   return 0
}

# Prints the entry in the static index containing a given sting value for a given attribute.
# All entries are taken from a given file defaulting to the static index file as defined by
# <lookup file: file paths>.
# The index file should only really be changed for testing purposes.
#
# Arguments:
# * <index file> passed automatically by the alias
# * <attribute identifier> possible values: "server-id", "class-name", "config-file", "file-path"
# * <string value>
#
# Return status:
# 0: success
# 1: <attribute identifier> was invalid
# 2: <string value> is not an existing value for the attribute in the index file
alias static_index_entry_for_="_static_index_entry_for_ '$dot/../$(path_for_ static-index)' "
function _static_index_entry_for_ {
   # Gets the column that needs to be checked in the index file from the given attribute
   # indentifier, or prints an error message and returns on failure if it is invalid.
   index_column=$(column_number_for_ "$2" --in static-index) || return 2

   # Prints the entry in the index corresponding to where the <string value> is located in the
   # attribute column, or returns on error if none was found.
   _index_entries_in_file_for_column_matching_value_ "$1" $index_column "$3" || return 2

   return 0
}

# Prints the entry in the runtime index containing a given sting value for a given attribute.
# All entries are taken from a given file defaulting to the runtime index file as defined by
# <lookup file: file paths>.
# The index file should only really be changed for testing purposes.
#
# Arguments:
# * <index file> passed automatically by the alias
# * <attribute identifier> possible values: "instance-id", "server-id", "config-file"
# * <string value>
#
# Return status:
# 0: success
# 1: <attribute identifier> was invalid
# 2: <string value> is not an existing value for the attribute in the index file
alias runtime_index_entries_for_="_runtime_index_entries_for_ '$dot/../$(path_for_ runtime-index)' "
function _runtime_index_entries_for_ {
   # Gets the column that needs to be checked in the index file from the given attribute
   # indentifier, or prints an error message and returns on failure if it is invalid.
   index_column=$(column_number_for_ "$2" --in runtime-index) || return 2

   # Prints the entries in the index corresponding to where the <string value> is located in the
   # attribute column, or returns on error if none was found.
   _index_entries_in_file_for_column_matching_value_ "$1" $index_column "$3" || return 2

   return 0
}


# Prints the field for a given attribute, in the static index, that's on the same row as a given
# string value for another attribute.
# All entries are taken from a given file defaulting to the static index file as defined by
# <lookup file: file paths>.
# The index file should only really be changed for testing purposes.
#
# Arguments:
# * <index file> passed automatically by the alias
# * <target attribute> possible values: "server-id", "class-name", "config-file", "file-path"
# * <for flag> possible values: "--for"
# * <source attribute> possible values: "server-id", "class-name", "config-file", "file-path"
# * <source field>
#
# Return status:
# 0: success
# 1: <target attribute>, <source attribute>, or <for flag> was invalid
# 2: <source field> is not an existing value for the attribute in the index file
alias static_="_static_ '$dot/../$(path_for_ static-index)' "
function _static_ {
   # Binds the target column.
   target_column=$(column_number_for_ "$2" --in static-index) || return 1

   # Makes sure the <for flag> was passed.
   if [ "$3" != '--for' ]; then
      echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$3\"" >&2
      return 1
   fi

   # Gets the entry in the index corresponding to where the <source field> is located in its
   # attribute column, or returns on error if none was found.
   index_entry=$(_static_index_entry_for_ "$1" "$4" "$5") || return 2

   # Prints the field of the target attribute in the source's row.
   cut -d : -f $target_column <<< "$index_entry"

   return 0
}

# Prints the fields for a given attribute, in the runtime index, that are on the same rows as a
# given string value for another attribute.
# All entries are taken from a given file defaulting to the runtime index file as defined by
# <lookup file: file paths>.
# The index file should only really be changed for testing purposes.
#
# Arguments:
# * <index file> passed automatically by the alias
# * <target attribute> possible values: "instance-id", "server-id", "config-file"
# * <for flag> possible values: "--for"
# * <source attribute> possible values: "instance-id", "server-id", "config-file"
# * <source field>
#
# Return status:
# 0: success
# 1: <target attribute>, <source attribute>, or <for flag> was invalid
# 2: <source field> is not an existing value for the attribute in the index file
alias runtime_="_runtime_ '$dot/../$(path_for_ runtime-index)' "
function _runtime_ {
   # Binds the target column.
   target_column=$(column_number_for_ "$2" --in runtime-index) || return 1

   # Makes sure the <for flag> was passed.
   if [ "$3" != '--for' ]; then
      echo "Error: \`${FUNCNAME[0]}\` received invalid flag \"$3\"" >&2
      return 1
   fi

   # Gets the entries in the index corresponding to where the <source field> is located in its
   # attribute column, or returns on error if none were found.
   index_entries=$(_runtime_index_entries_for_ "$1" "$4" "$5") || return 2

   # Prints the fields of the target attribute in the source's rows.
   while read index_entry; do
      cut -d : -f $target_column <<< "$index_entry"
   done <<< "$index_entries"

   return 0
}


#-Cleanup---------------------------------------#


# Resets the $dot-variable to its previous value.
dot="$previous_dot"
