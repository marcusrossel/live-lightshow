#!/bin/bash

# This script updates a given file to contain only the trait-declarations corresponding to a given
# configuration file.
#
# Arguments:
# * <configuration file>
# * <program file> optional, for testing purposes
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: an entry in <configuration file> is malformed
# 3: <configuration file> contains duplicate trait-identifiers

# TODO: Increases the space after the trait-declarations each time. Fix that.
# TODO: Figure out how to handle the trait-declaration-body-variables not being renamable.
# >> Perhaps have a compiletime-configuration file that also stores the variable names, from which
# >> then is generated the runtime-configuration file. And both are then passed to apply
# >> configuration, which can then (a) use the correct variable names and (b) check during runtime
# >> whether a given trait-identifier is even valid.
# >> The java Configuration class uses its hardcoded values, if a trait it missing in the runtime-
# >> configuration file.


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports lookup and utilities.
. "$_dot/../../Utility Scripts/lookup.sh"
. "$_dot/../../Utility Scripts/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   # Binds a command line argument.
   readonly configuration_file=$1

   # Sets the location of the <program file> as the second command line argument, or to the one
   # specified by <lookup file: item names> if none was passed.
   if [ -n "$2" ]; then
      readonly ino_file=$2
   else
      local -r program_directory="$dot/../../$(path_for_ lightshow-directory)"
      readonly program_file="$program_directory/$(name_for_ lightshow-program)"
   fi
}


#-Functions-------------------------------------#


# Makes sure a given configuration file contains only valid entries and no duplicate identifiers. If
# not, an error is printed and a return on failure occurs.
#
# Arguments:
# * <configuration file>
#
# Return status:
# 0: success
# 1: found a malformed configuration entry
# 2: found duplicate trait identifiers
function assert_configuration_validity_ {
   # Asserts the validity of the <configuration file>'s entries. If any are invalid, an error is
   # printed and a return on failure occurs.
   if egrep -vq "$(regex_for_ configuration-entry)" "$1"; then
      echo "Error: \`${BASH_SOURCE##*/}\` received configuration containing malformed entry" >&2
      return 1
   fi

   # Gets a list of the <configuration file>'s duplicate trait identifiers.
   local -r duplicate_trait_IDs=$(cut -d : -f 1 "$1" | sort | uniq -d)

   # Returns successfully if no duplicates were found.
   [ -z "$duplicate_trait_IDs" ] && return 0

   # Prints and error message for each duplicate.
   while read -r duplicate; do
      # Gets the lines of the duplicates in a comma-seperated list.
      local -e line_number_list=$(egrep -n "^$duplicate:" "$1" | cut -d : -f 1 | paste -s -d , -)
      echo "Error: \`$1\` lines $line_number_list: duplicate trait-identifiers" >&2
   done <<< "$duplicate_trait_IDs"

   return 2
}

# Prints the line numbers of all of the lines containing trait-declaration headers or bodies in a
# given file.
#
# Arguments:
# * <file>
function declaration_line_numbers_in {
   # Starts the counter at `1`.
   local line_counter=1

   # Reads the <file> line by line.
   while read -r line; do
      # Checks if the current line is a header, in which case its line number and the following one
      # are printed (as the line following a header is considered its body).
      if egrep -q "$(regex_for_ trait-header)" <<< "$line"; then
         echo -n "$line_counter\n$((line_counter + 1))"

      # Checks if the current line is the trait declarations end tag, in which case no further lines
      # need to be read.
   elif egrep -q "$(regex_for_ traits-end-tag)" <<< "$line"; then
         echo $line_counter
         break
      fi

      # Increments the line counter, no matter what was read.
      ((line_counter++))
   done < "$1"

   return 0
}

# Prints all of the trait-declarations equivalent to the entries in a given configuration file.
#
# Arguments:
# * <configuration file>
function trait_declarations_for_configuration {
   # Keeps a counter of the number of trait declarations, as identifier for each.
   local declaration_counter=0

   while read -r configuration_entry; do
      # Reads the next entry if the current one was empty.
      [ -z "$configuration_entry" ] && continue

      # Extracts the microphone-identifier and threshold-value from the current configuration entry.
      microphone_id=`cut -d : -f 1 <<< "$configuration_entry"`
      threshold_value=`cut -d : -f 2 <<< "$configuration_entry"`

      # Prints a treshold-declaration header and body using the components above. The identifier of
      # the printed integer-constant is affected by the declaration counter.
      echo "// #trait \"$microphone_id\""
      echo "const int threshold_declaration_${declaration_counter}_value =$threshold_value;"
      echo

      (( declaration_counter++ ))
   done < "$1"

   # Prints the "threshold declarations end"-tag
   echo '// #threshold-declarations-end'
}


#-Main------------------------------------------#


assert_correct_argument_count_ 1 2 '<configuration file> <.ino file: optional>' || exit 1
declare_constants "$@"

# Makes sure the configuration file is wellformed, or returns on failure.
assert_configuration_validity_ "$configuration_file" || exit $(($?+2))

# Gets the line numbers of all of the lines containing threshold-declarations.
readonly declaration_line_numbers=`declaration_line_numbers_in "$ino_file"`

# Removes all of the current threshold-declarations (in reverse order, so removal of one line does
# not affect the line number of another).
tail -r <<< "$declaration_line_numbers" | while read line_to_delete; do
   # Removes the line with the determined number inplace from the <.ino file>.
   sed -i '' -e "${line_to_delete}d" "$ino_file"
done

# Sets the line at which the new declarations should be inserted, as the line of what was previously
# the first declaration.
readonly declaration_insertion_point=`head -n 1 <<< "$declaration_line_numbers"`

# Generates threshold-declarations from the new configuration.
readonly new_declarations=`threshold_declarations_for_configuration "$configuration_file"`

# Inserts the generated declarations at the insertion point.
ex -s -c "${declaration_insertion_point}i|$new_declarations" -c 'x' "$ino_file"

# TODO: Remove any uses of "threshold_declaration_[n >= number of declarations]_value".
