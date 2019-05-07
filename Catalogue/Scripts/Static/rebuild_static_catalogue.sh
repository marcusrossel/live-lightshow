#!/bin/bash

# This script parses the files in the servers' program directory and updates the static-index and
# static config- and info-files from the results.
#
# Return status:
# 0: success
# 1: invalid number of command line arguments


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../../../Utilities/scripting.sh"
. "$dot/../../../Utilities/lookup.sh"
. "$dot/../../../Utilities/data.sh"
. "$dot/../../../Utilities/parsing.sh"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   readonly static_index="$dot/../../../$(path_for_ static-index)"
   readonly servers_directory=$(realpath "$dot/../../../$(path_for_ servers-directory)")
   readonly static_data_directory=$(realpath "$dot/../../../$(path_for_ static-data-directory)")
   readonly info_file_suffix=$(name_for_ server-info-file-suffix)
   readonly buffer_file_suffix='-buffer'

   return 0
}

#-Main------------------------------------------#


assert_correct_argument_count_ 0 || exit 1
declare_constants "$@"

# Creates a buffer for the new static index, and a flag for recording whether an error occured..
new_static_index=''
error_occured=false

# Iterates over the files in the servers' program directory.
server_counter=0
for file in $(ls "$servers_directory"); do
   file="$servers_directory/$file"

   # Gets the parse-list for the given file, or the error messages if the file contained errors.
   parse_list=$(parse_list_for_ "$(token_list_for "$file")" "$file" 2>&1)
   # Sets the error flag and prints an error if the file contained errors upon parsing.
   if [ $? -eq 1 ]; then
      error_occured=true
      echo -e "The server-file '$print_yellow$file$print_normal' contains the following errors:\n" \
              "$parse_list" >&2
      continue
   elif [ -z "$parse_list" ] || $error_occured; then
      # Files with empty parse-lists do not contain server, so the steps below can be skipped.
      # Also, after a server-file has failed the creation of its parse-list, other servers are only
      # relevant in terms of their errors - so all steps below can be skipped.
      continue
   fi

   # Adds the static-index entry for the current file.
   server_name=$(parse_ server-name --from "$parse_list" --of "$file")
   server_class=$(parse_ server-class --from "$parse_list" --of "$file")
   config_file="$static_data_directory/$server_counter"
   new_static_index="$new_static_index$server_name:$server_class:$file:$config_file$newline"

   # Creates the configuration-file-buffer for the current file.
   config_buffer="$config_file$buffer_file_suffix"
   parse_ server-configuration --from "$parse_list" --of "$file" > "$config_buffer"
   echo "$(name_for_ config-read-cycle-trait):5.0:float" >> "$config_buffer"

   # Creates the info-file-buffer for the current file.
   info_buffer="$config_file$info_file_suffix$buffer_file_suffix"
   parse_ info-text --from "$parse_list" --of "$file" > "$info_buffer"

   ((server_count++))
done

# Returns on failure after removing buffer-files and without writing a new static-index, if an error
# occured.
if $error_occured; then
   data_for_ config-file --in static-index --entries "$new_static_index" |
   while read -r buffered_config_file; do
      # TODO: Make this rm when safe.
      rem "$buffered_config_file$buffer_file_suffix"
      rem "$buffered_config_file$info_file_suffix$buffer_file_suffix"
   done

   exit 1
fi

# Writes the new static-index.
echo -n "$new_static_index" >"$static_index"

# TODO: Change this to: remove all file not ending in -buffer, then rename those which do.
# Merges the configuration and info-file-buffers into the actual configuration- and info-files.
data_for_ config-file --in static-index | while read -r config_file; do
   silently- rm "$config_file"
   silently- rm "$config_file$info_file_suffix"

   mv "$config_file$buffer_file_suffix" "$config_file"
   mv "$config_file$info_file_suffix$buffer_file_suffix" "$config_file$info_file_suffix"
done

exit 0
