#!/bin/bash

# This script updates a given `.ino`-file to contain only the threshold-declarations corresponding
# to a given configuration file.
#
# Arguments:
# * <configuration file>
# * <.ino file> optional, for testing purposes
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: a given file was not readable or has the wrong file type
# 3: an entry in <configuration file> is malformed
# 4: <configuration file> contains duplicate microphone-identifiers

# TODO: Increases the space after the threshold-declarations each time. Fix that.


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
   # Binds command line arguments.
   readonly configuration_file=$1

   # Sets the location of the <.ino file> as the first command line argument, or to the one
   # specified by <utility file: file locations> if none was passed.
   if [ -n "$2" ]; then
      readonly ino_file=$2
   else
      local -r program_folder="$dot/../../`location_of_ --repo-program-directory`"
      readonly ino_file="$program_folder/`ls -1 "$program_folder" | egrep '\.ino$'`"
   fi
}


#-Functions-------------------------------------#


# Makes sure a given configuration file contains only valid entries and no duplicate identifier. If
# not an error is printed and a return on failure occurs.
#
# Arguments:
# * <configuration file>
#
# Return status:
# 0: success
# 1: found a malformed configuration entry
# 2: found duplicate microphone identifiers
function assert_configuration_validity_ {
   # Asserts the validity of the <configuration file>'s entries. If any are invalid, an error is
   # printed and a return on failure occurs.
   if egrep -vq "`regex_for_ --configuration-entry`" "$1"; then
      echo "Error: \`${BASH_SOURCE##*/}\` received configuration containing malformed entry" >&2
      return 1
   fi

   # Gets a list of the <configuration file>'s duplicate microphone identifiers.
   local -r duplicate_microphone_ids=`cut -d : -f 1 "$1" | sort | uniq -d`

   # Returns successfully if no duplicates were found.
   [ -z "$duplicate_microphone_ids" ] && return 0

   # Prints and error message for each duplicate.
   while read -r duplicate; do
      # Gets the lines of the duplicates in a comma-seperated list.
      local -e line_number_list=`egrep -n "^$duplicate:" "$1" | cut -d : -f 1 | paste -s -d , -`
      echo "Error: \`$1\` lines $line_number_list: duplicate microphone-identifiers" >&2
   done <<< "$duplicate_microphone_ids"

   return 2
}

# Prints the line numbers of all of the lines containing threshold-declaration headers or bodies in
# a given file.
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
      if egrep -q "`regex_for_ --header`" <<< "$line"; then
         echo $line_counter
         echo $[line_counter + 1]

      # Checks if the current line is the "threshold declarations end"-tag, in which case no further
      # lines need to be read.
      elif egrep -q "`regex_for_ --end-tag`" <<< "$line"; then
         echo $line_counter
         break
      fi

      # Increments the line counter, no matter what was read.
      (( line_counter++ ))
   done < "$1"

   return 0
}

# Prints all of the threshold-declarations equivalent to the entries in a given configuration file.
#
# Arguments:
# * <configuration file>
function threshold_declarations_for_configuration {
   # Keeps a counter of the number of threshold declarations as identifier for each.
   local declaration_counter=0

   while read -r configuration_entry; do
      # Reads the next entry if the current one was empty.
      [ -z "$configuration_entry" ] && continue

      # Extracts the microphone-identifier and threshold-value from the current configuration entry.
      microphone_id=`cut -d : -f 1 <<< "$configuration_entry"`
      threshold_value=`cut -d : -f 2 <<< "$configuration_entry"`

      # Prints a treshold-declaration header and body using the components above. The identifier of
      # the printed integer-constant is affected by the declaration counter.
      echo "// #threshold \"$microphone_id\""
      echo "const int threshold_declaration_${declaration_counter}_value =$threshold_value;"
      echo

      (( declaration_counter++ ))
   done < "$1"

   # Prints the "threshold declarations end"-tag
   echo '// #threshold-declarations-end'
}


#-Main------------------------------------------#


assert_correct_argument_count_ 1 2 '<configuration file> <.ino file: optional>' || exit 1 #RS=1
declare_constants "$@"

# Makes sure the given files are valid and wellformed, or returns on failure.
assert_path_validity_ "$ino_file" --ino || exit 2 #RS=2
assert_path_validity_ "$configuration_file" || exit 2 #RS=2
assert_configuration_validity_ "$configuration_file" || exit $[$?+2] #RS+2=4

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
