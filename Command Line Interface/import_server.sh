#!/bin/bash

# This script adds a given server file to the set of servers - if possible.
#
# Arguments:
# * <server file>
# * <custom server name> optional
#
# Return status:
# 0: success
# 1: the given file path is not a regular file
# 2: the given server file contains errors
# 3: the given file does not define a server
# 4: the given custom name is malformed
# 5: the server name (or if given, the custom server name) is already in use
# 6: the server's class name is already in use
# 7: the server's file name is already in use


#-Preliminaries---------------------------------#


# Gets the directory of this script.
dot=$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)")
# Imports.
. "$dot/../Utilities/scripting.sh"
. "$dot/../Utilities/lookup.sh"
. "$dot/../Utilities/data.sh"
. "$dot/../Utilities/parsing.sh"


#-Main------------------------------------------#


readonly importee=$1; shift
readonly custom_name=$@

# assert_correct_argument_count_ 1 2 '<server file> <custom server name: optional>' || exit 1
if [ -z "$importee" ]; then
   echo -e "${print_red}This subcommand expects a file as argument.$print_normal" >&2
   exit 1
elif ! [ -f "$importee" ]; then
   echo -e "${print_red}The given path does not point to a program file.$print_normal" >&2
   exit 1
fi

echo -e "${print_green}Checking server file validity...$print_normal" >&2

# Gets the token-list for the given file.
readonly token_list=$(token_list_for "$importee")

# Gets the parse-list for the given file, or the error messages if the file contained errors.
parse_list=$(parse_list_for_ "$token_list" "$importee" 2>&1)
# Prints an error if the file contained errors upon parsing, and returns on failure.
if [ $? -eq 1 ]; then
   echo -e "The given file contains the following errors:\n$parse_list" >&2
   exit 2
# Prints an error if the given file does not define a server and returns on failue.
elif [ -z "$parse_list" ]; then
   echo -e "${print_red}The given file does not define a server.$print_normal" >&2
   exit 3
fi

# Gets the parsed server-name, or the custom server-name if given.
if [ -n "$custom_name" ]; then
   # Makes sure the custom server-name is valid.
   if egrep -qv "$(regex_for_ server-name)" <<< "$custom_name"; then
      echo -e "The given server name '$print_yellow$custom_name$print_normal' is invalid." >&2
      echo -e "Server names may not include the characters $print_yellow:$print_normal and" \
              "$print_yellow\"$print_normal." >&2
      exit 4
   fi

   readonly server_name="$custom_name"
else
   readonly server_name=$(parse_ server-name --from "$parse_list" --of "$importee")
fi

# Checks if the server-name (possibly the custom one) is already taken.
readonly taken_server_names=$(data_for_ server-name --in static-index)
if $(string_ "$server_name" --is-line-in-string "$taken_server_names"); then
   echo -e "The server name '$print_yellow$server_name$print_normal' is already being used." >&2
   echo -e "Please define a different custom name, when importing the server." >&2
   exit 5
fi

# Checks if the server-class is already taken.
# TODO: Check all class names in the given file against all class names in all program files.
# > readonly given_class_names=$(
# >   fields_for_ token-value --with token-type class-name --in token-list --entries "$token_list"
# > )

# Checks if the file name is already taken.
readonly servers_directory="$dot/../$(path_for_ servers-directory)"
readonly file_name=$(basename "$importee")
taken_file_names="$(ls "$dot/../$(path_for_ lightshow-directory)")$newline"
taken_file_names="$taken_file_names$(ls "$servers_directory")"

if $(string_ "$file_name" --is-line-in-string "$taken_file_names"); then
   echo -e "The file name '$print_yellow$file_name$print_normal' is already being used." >&2
   echo -e "Please change the file name and try importing again." >&2
   exit 7
fi


# Adds the given file to the server files and rebuilds the static catalogue.
cp "$importee" "$servers_directory/$file_name"

# Overwrites the server-declaration in the source file with the custom name.
if [ -n "$custom_name" ]; then
   # Gets the line of the server-declaration in the source file.
   readonly server_declaration_line=$(
      fields_for_ line-number --with seme-type server-name --in parse-list --entries "$parse_list"
   )
   # Creates the new server-declaration.
   readonly new_declaration="// #server \"$custom_name\""

   # Removes the previous server-declaration from the server file.
   sed -i '' -e "${server_declaration_line}d" "$servers_directory/$file_name"

   # Writes the new server-declaration into the server file.
   ex -s -c "${server_declaration_line}i|$new_declaration" -c 'x' "$servers_directory/$file_name"
fi

echo -e "${print_green}Recataloguing server files...$print_normal" >&2

"$dot/../Catalogue/Scripts/Static/rebuild_static_catalogue.sh"

echo -e "${print_green}Import complete.$print_normal" >&2

exit 0
