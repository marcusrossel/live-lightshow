#!/bin/bash

# This script serves as a library of functions for parsing as used for indexing and cataloguing.
# It should be noted that this script activates alias expansion.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$PARSING_SH" ] && readonly PARSING_SH=true || return

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Gets the directory of this script.
dot_parsing=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot_parsing/scripting.sh"
. "$dot_parsing/lookup.sh"
. "$dot_parsing/data.sh"


#-Private-Functions-----------------------------#


# Prints a token-list, in which all entries lying within the info-section are removed.
# If there is no info-begin or info-end tag, nothing is removed.
# If there is only an info-begin tag, the info-section reaches to the end of the file.
# If there is only an info-end tag, the info-section starts at the beginning of the file.
# If there are multiple info-begin and/or info-end tags, the lines with the duplicates and tag-type
# are printed and a return on failure occurs.
#
# Arguments:
# * <token list>
#
# Return status:
# 0: success
# 1: multiple info-begin and/or info-end tags were found
function _infoless_token_list_ {
   # Gets the list of token-types from the token-list and the column used for token-values in token
   # lists.
   local -r token_type_list=$(data_for_ token-type --in token-list --entries "$1")
   local -r token_value_column=$(column_for_ token-value --in token-list)

   # Gets the lines of the info-begin and info-end declarations in the token-list.
   local -r begin_tag_lines=$(line_numbers_of_string_ info-begin --in-string "$token_type_list")
   local -r end_tag_lines=$(line_numbers_of_string_ info-end --in-string "$token_type_list")

   # Creates a flag to determine whether an error occured.
   local error_occured=false

   # Prints error information and returns on failure if either type of tag occurs multiple times.
   if [ "$(wc -l <<< "$begin_tag_lines")" -gt 1 ]; then
      # Gets the in-program line numbers of the tags.
      local -r begin_tag_values=$(
         fields_for_ token-value --with token-type info-begin --in token-list --entries "$1"
      )

      # Prints the duplicate lines in a formatted way, and sets the error-flag.
      echo -n 'info-begin:'; paste -s -d, - <<< "$begin_tag_values"
      error_occured=true
   fi
   if [ "$(wc -l <<< "$end_tag_lines")" -gt 1 ]; then
      # Gets the in-program line numbers of the tags and prints them in a formatted way.
      local -r end_tag_values=$(
         fields_for_ token-value --with token-type info-end --in token-list --entries "$1"
      )

      # Prints the duplicate lines in a formatted way, and sets the error-flag.
      echo -n 'info-end:'; paste -s -d, - <<< "$end_tag_values"
      error_occured=true
   fi

   # Returns on failure if an error occured.
   $error_occured && return 1

   # Prints the token-list without the declarations within the info-section.
   [ -z "$begin_tag_lines" -a -z "$end_tag_lines" ] && { echo "$1"; return 0; }
   [ -n "$begin_tag_lines" ] && head -n "$begin_tag_lines" <<< "$1"
   [ -n "$end_tag_lines" ] && tail -n "+$end_tag_lines" <<< "$1"

   return 0
}

# Prints a token-list in which all class-declarations, except for the one following a given line
# number (of the server-declaration), are removed.
# If there is no class-declaration below the given line number, a return on failure occurs.
#
# Arguments:
# * <token list>
# * <server name line number>
#
# Return status:
# 0: success
# 1: no class was found beneath the server-name declaration
function _single_class_token_list_ {
   # Gets the line number at which a class-declaration is required.
   local -r required_line_number=$(($2 + 1))

   # Gets the column of the token-type and line-number in token-lists.
   local -r token_type_column=$(column_for_ token-type --in token-list)
   local -r line_number_column=$(column_for_ line-number --in token-list)

   # Initializes an output buffer and a flag indicating whether the required class name has been
   # read.
   local output=''
   local did_read_required_class_name=false

   # Iterates over the entries in the token-list.
   while read -r entry; do
      if [ "$(cut -d : -f "$token_type_column" <<< "$entry")" != class-name ]; then
         # Simply adds entries that are not class-names to the output buffer.
         output="$output$entry$newline"
         continue
      elif $did_read_required_class_name; then
         # Skips any class-name entries after the required one has been read.
         continue
      else
         # Checks if the given class-name entry is at the required line number. If so, it adds it to
         # the output buffer and sets the corresponding flag.
         local line_number=$(cut -d : -f "$line_number_column" <<< "$entry")
         if [ "$line_number" -eq "$required_line_number" ]; then
            output="$output$entry$newline"
            did_read_required_class_name=true
         fi
      fi
   done <<< "$1"

   # Returns on success or failure according to whether or not the required class name was read.
   $did_read_required_class_name && { echo "$output"; return 0; } || return 1
}


#-Public-Functions------------------------------#


# Prints the type of a given value. Possible types are:
# "int", "float", "bool", "int-list", "float-list", "bool-list"
#
# Arguments:
# * <value>
#
# Return status:
# 0: success
# 1: <string> has none of the defined types
function type_for_value_ {
   egrep -q "$(regex_for_ int)"        <<< "$1" && { echo 'int';        return 0; }
   egrep -q "$(regex_for_ float)"      <<< "$1" && { echo 'float';      return 0; }
   egrep -q "$(regex_for_ bool)"       <<< "$1" && { echo 'bool';       return 0; }
   egrep -q "$(regex_for_ int-list)"   <<< "$1" && { echo 'int-list';   return 0; }
   egrep -q "$(regex_for_ float-list)" <<< "$1" && { echo 'float-list'; return 0; }
   egrep -q "$(regex_for_ bool-list)"  <<< "$1" && { echo 'bool-list';  return 0; }

   # If this point was reached no type matched, so a return on failure occurs.
   return 1
}

# Prints a token-list for a given program file. The list has the form:
# <line number 1>:<token 1 type>:<token 1 value>
# <line number 2>:<token 2 type>:<token 2 value>
# ...
#
# Possible values for <token type> are:
# "server-name", "class-name", "trait-name", "trait-value", "info-begin", "info-end"
#
# Arguments:
# * <program file>
function token_list_for {
   # Gets the regular expression patterns used for lexical analysis.
   local -r trait_pattern=$(regex_for_ trait)
   local -r server_declaration_pattern=$(regex_for_ server-declaration)
   local -r class_declaration_pattern=$(regex_for_ class-declaration)
   local -r info_begin_pattern=$(regex_for_ server-info-begin-tag)
   local -r info_end_pattern=$(regex_for_ server-info-end-tag)

   # Iterates over the lines in the given program file.
   local line_count=1
   while read -r line; do
      # Handles trait declarations.
      if egrep -q "$trait_pattern" <<< "$line"; then
         # Extracts and prints the components of the trait declaration.
         local trait_name=$(echo "$line" | cut -d '"' -f 2 | trimmed)
         local trait_value=$(echo "$line" | cut -d : -f 2 | trimmed)

         echo "$line_count:trait-name:$trait_name"
         echo "$line_count:trait-value:$trait_value"

      # Handles server declarations.
      elif egrep -q "$server_declaration_pattern" <<< "$line"; then
         # Extracts and prints the server name of the server declaration.
         local server_name=$(echo "$line" | cut -d '"' -f 2 | trimmed)
         echo "$line_count:server-name:$server_name"

      # Handles server class declaration.
      elif egrep -q "$class_declaration_pattern" <<< "$line"; then
         # Extracts and prints the class name of the class declaration.
         local name_declaration=$(egrep -o 'class\s+[a-zA-Z_][a-zA-Z0-9_]*' <<< "$line")
         local class_name=$(echo "$name_declaration" | tr -s ' ' | cut -d ' ' -f 2)
         echo "$line_count:class-name:$class_name"

      # Handles server-info-begin tags.
      elif egrep -q "$info_begin_pattern" <<< "$line"; then
         echo "$line_count:info-begin:$line_count"

      # Handles server-info-end tags.
      elif egrep -q "$info_end_pattern" <<< "$line"; then
         echo "$line_count:info-end:$line_count"
      fi

      ((line_count++))
   done < "$1"

   return 0
}

# Filteres and changes the tokens contained in the given token-list, to contain those which are
# relevant for parsing. Also, if errors are detected in the token-list's entries, they are pretty
# printed and a return on failure occurs.
# The parse list has the form:
# <token 1 type>:<token 1 value>
# <token 2 type>:<token 2 value>
# ...
#
# This list will contain at most one server-name, class-name, info-begin and info-end entry.
# Trait values are assured to appear in the entry right after the corresponing trait name in the
# list.
# Any tokens lying in the info-section will not appear in the parse-list.
#
# Arguments:
# * <token list>
# * <program file>
#
# Return status:
# 0: success
# 1: the token-list contains errors
function parse_list_for_ {
   # Creates a flag to determine whether an error occured.
   local error_occured=false

   # Gets the token-list with any tokens lying in the info-section removed.
   local infoless_token_list; infoless_token_list=$(_infoless_token_list_ "$1")
   # Handles the case that multiple info-begin and/or info-end tokens were found.
   if [ $? -eq 1 ]; then
      error_occured=true

      while read -r error_report; do
         local tag_description=$(cut -d : -f 1 <<< "$error_report")
         local tag_lines=$(cut -d : -f 2 <<< "$error_report")

         echo -e "In file '$print_yellow$2$print_normal': Multiple $print_yellow#$tag_description" \
                 "${print_normal}tags were found on lines $tag_lines." >&2
      done <<< "$infoless_token_list"
   fi

   # If the given file contains no server declaration, return on success with no output. If it
   # contains multiple, print an error.
   local -r server_name_line=$(
      fields_for_ line-number --with token-type server-name --in token-list --entries "$1"
   )
   if [ -z "$server_name_line" ]; then return 0
   elif [ "$(wc -l <<< "$server_name_line")" -gt 1 ]; then
      echo -e "In file '$print_yellow$2$print_normal': Multiple $print_yellow#server$print_normal" \
              "tags were found on lines $(paste -s -d, - <<< "$server_name_line")." >&2
   fi

   # Gets the token list, with any non-server class-declarations removed.
   local clean_token_list
   clean_token_list=$(_single_class_token_list_ "$infoless_token_list" "$server_name_line")
   # Handles the case that no class was declared for the given server.
   if [ $? -eq 1 ]; then
      error_occured=true

      local -r server_name=$(
         fields_for_ token-value --with token-type server-name --in token-list --entries "$1"
      )

      echo -e "In file '$print_yellow$2$print_normal': The server declaration for" \
              "'$print_yellow$server_name$print_normal' requires a class-declaration at line" \
              "$((server_name_line + 1)), which is missing." >&2
   fi

   # Creates the parse list.
   local -ir line_number_column=$(column_for_ line-number --in token-list)
   # TODO: Make this use the $line_number_column.
   local -r parse_list=$(cut -d : -f 2- <<< "$clean_token_list")

   # Returns on success or failure according to whether or not an error occured.
   $error_occured && return 1 || { echo "$parse_list" ; return 0; }
}

# Prints a list of items of a given type given a program file and its parse-list.
#
# Arguments:
# * <item type ID> possible values: "server-name", "server-class", "trait-declarations", "info-text"
# * <from flag> possible values: "--from"
# * <parse list>
# * <of flag> possible values: "--of"
# * <program file>
#
# Return status:
# 0: success
# 1: the given <from flag>, <for flag> or <item type ID> is invalid
function parse_ {
   # Makes sure the <from flag> and <of flag> is valid.
   [ "$2" = '--from' ] || { print_error_for --flag "$2"; return 1; }
   [ "$4" = '--of' ] || { print_error_for --flag "$4"; return 1; }

   # Behaves differently for each item type.
   case "$1" in
      server-name)
         fields_for_ seme-value --with seme-type server-name --in parse-list --entries "$3" ;;

      server-class)
         fields_for_ seme-value --with seme-type class-name --in parse-list --entries "$3" ;;

      trait-declarations)
         # Gets the list of seme-types from the parse-list and the column for seme-values in
         # parse-lists.
         local -r seme_type_list=$(data_for_ seme-type --in parse-list --entries "$3")
         local -r seme_value_column=$(column_for_ seme-value --in parse-list)
         # echo "$seme_type_list" >&2
         # echo "$seme_value_column" >&2

         # Iterates over the line numbers of the parse-list entries containing trait names.
         line_numbers_of_string_ trait-name --in-string "$seme_type_list" | while read -r line; do
            # Gets the trait declaration components.
            local trait_name=$(
               line_ "$line" --in-string "$3" | cut -d : -f "$seme_value_column"
            )
            local trait_value=$(
               line_ "$((line + 1))" --in-string "$3" | cut -d : -f "$seme_value_column"
            )
            local trait_type=$(type_for_value_ "$trait_value")

            # Prints the server declaration.
            echo "$trait_name:$trait_value:$trait_type"
         done ;;

      info-text)
         # Gets the line numbers of the info-begin and info-end tags.
         local -r begin_tag_line=$(
            fields_for_ seme-value --with seme-type info-begin --in parse-list --entries "$3"
         )
         local -r end_tag_line=$(
            fields_for_ seme-value --with seme-type info-end --in parse-list --entries "$3"
         )

         # Prints the lines between the begin and end tag, if at least one of them was set.
         if [ -n "$end_tag_line" ]; then
            local -r begin_line=${begin_tag_line-0}
            line_ "$((begin_line + 1))" --to "$((end_tag_line - 1))" --in-file "$5"
         elif [ -n "$begin_tag_line" ]; then
            tail "+$((begin_tag_line + 1))" "$5"
         fi ;;

      *)
         print_error_for --identifier "$1"; return 1 ;;
   esac

   return 0
}
