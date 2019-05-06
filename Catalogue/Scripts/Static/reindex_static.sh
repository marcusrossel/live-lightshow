#!/bin/bash

# This script generates a new static index and with a corresponding static configuration directory.
# Older, unused configuration files will remain in the static configuration directory, but will not
# affect anything.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: a file contained problematic server-info tags

# TODO: There are two steps performed statically: indexing and recording/itemizing.
# > Create something like a simple parse-list to make this process übersichtlicher and improve error
# > reporting.
# > Design utility files accordingly.


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly static_index="$dot/../../../$(path_for_ static-index)"

   return 0
}


#-Functions-------------------------------------#


# Prints the line number of a given info-tag type in a given progrem file.
#
# Arguments:
# * <info tag type flag> possible values: "--begin", "--end"
# * <program file>
#
# Return status:
# 0: success
# 1: the given flag was invalid
# 2: no tag line was found
# 3: multiple tag lines were found
function info_tag_line_ {
   # Gets the pattern associated with the tag for the given flag.
   case "$1" in
      --begin) local -r tag_pattern=$(regex_for_ server-info-begin-tag) ;;
      --end)   local -r tag_pattern=$(regex_for_ server-info-end-tag) ;;
      *)       print_error_for --flag "$1"; return 1 ;;
   esac

   # Gets the tag line with line number.
   local -r tag_line=$(egrep -n "$tag_pattern" "$2")

   # Asserts that there is exactly one tag line.
   [ -z "$tag_line" ] && return 2
   [ $(wc -l <<< "$tag_line") -gt 1 ] && return 3

   # Prints the line number and returns on success, if exactly one tag line was found.
   cut -d : -f 1 <<< "$tag_line"
   return 0
}

# Prints the info-section of a given program file if there is one.
#
# Arguments:
# * <program file>
#
# Return status:
# 0: success
# 1: the program file declares no info-section
# 2: problematic server-info tags
function server_info_for_file_ {
   # Gets the lines of the info-begin and info-end tags.
   info_begin_line=$(info_tag_line_ --begin "$1"); local -ir begin_tag_status=$?
   info_end_line=$(info_tag_line_ --end "$1"); local -ir end_tag_status=$?

   # Aborts if info-tags were declared improperly, or returns early if none were declared.
   if [ "$begin_tag_status" -eq 2 -a "$end_tag_status" -eq 2 ]; then
      return 1
   elif ! [ "$begin_tag_status" -eq 0 -a "$end_tag_status" -eq 0 ]; then
      print_error_for "Function received file '$print_yellow$1$print_red' with improperly" \
                      "declared info-tags.";
      return 2
   fi

   # Prints the lines between the tags.
   line_ "$((info_begin_line + 1))" --to "$((info_end_line - 1))" --in-file "$1"

   return 0
}

# Prints the static configuration corresponding to the trait declarations contained in a given file.
#
# A static configuration has the form:
# <trait 1 ID>:<trait 1 value>:<trait 1 type>
# <trait 2 ID>:<trait 2 value>:<trait 2 type>
# ...
#
# Arguments:
# * <program file>
#
# Return status:
# 0: success
# 1: internal error
# 2: problematic server-info tags
function static_configuration_for_file_ {
   # Gets the lines of the info-begin and info-end tags.
   info_begin_line=$(info_tag_line_ --begin "$1"); local -ir begin_tag_status=$?
   info_end_line=$(info_tag_line_ --end "$1"); local -ir end_tag_status=$?

   # Aborts if info-tags were declared improperly.
   if [ "$begin_tag_status" -eq 2 -a "$end_tag_status" -eq 2 ]; then
      info_begin_line=0; info_end_line=0;
   elif ! [ "$begin_tag_status" -eq 0 -a "$end_tag_status" -eq 0 ]; then
      print_error_for "Function received file '$print_yellow$1$print_red' with improperly" \
                      "declared info-tags."
      return 2
   fi

   # Gets and iterates over a list of line-numbered trait declarations in the given file.
   egrep -n "$(regex_for_ trait)" "$1" | while read trait_declaration; do
      # Skips to the next declaration if the line number of the current declaration falls between
      # the info-begin and info-end tag.
      local line_number=$(cut -d : -f 1 <<< "$trait_declaration")
      [ "$line_number" -ge "$info_begin_line" -a "$line_number" -le "$info_end_line" ] && continue

      # Extracts the parameters from the declaration.
      local trait_identifier=$(cut -d '"' -f 2 <<< "$trait_declaration")
      local trait_value=$(echo "$trait_declaration" | cut -d ':' -f 3 | trimmed)
      local trait_value_type
      if ! trait_value_type=$(type_for_value_ "$trait_value"); then
         # This should be unreachable.
         print_error_for --internal; return 1
      fi

      # Prints the entry for the current declaration.
      echo "$trait_identifier:$trait_value:$trait_value_type"
   done

   # Adds the configuration read cycle trait at a default value of 5 seconds.
   echo "$(name_for_ config-read-cycle-trait):5.0:float"

   return 0
}

# Sets up the static configuration file folder as to reflect the current static index. This entails # generating new configuration (and info-) files and overwriting old ones with the new information.
#
# Return status:
# 0: success
# 1: a file contained problematic server-info tags
function setup_static_configuration_files_ {
   # Iterates over the static index' entries.
   while read index_entry; do
      local program_file=$(data_for_ program-file --in static-index --entries "$index_entry")
      local config_file=$(data_for_ config-file --in static-index --entries "$index_entry")

      # Creates a new configuration file containing the appropriate static configuration.
      static_configuration_for_file_ "$program_file" > "$config_file" || return 1

      local info_file="$config_file$(name_for_ server-info-file-suffix)"

      # Creates a new server-info file containing the appropriate text, if the current server
      # declared an info-section.
      local server_info; server_info=$(server_info_for_file_ "$program_file")
      [ $? -ne 1 ] && echo "$server_info" > "$info_file"
   done < "$static_index"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Writes a new static index.
"$dot/static_index.sh" >"$static_index"

# Updates the static configuration directory.
setup_static_configuration_files_ || exit 2

exit 0
