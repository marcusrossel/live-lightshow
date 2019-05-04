#!/bin/bash

# This script serves as a library of functions for conveniently accessing this project's lookup
# files. It can be "imported" via sourcing.
# It should be noted that this script activates alias expansion.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$LOOKUP_SH" ] && readonly LOOKUP_SH=true || return

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Gets the directory of this script.
dot_lookup=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports.
. "$dot_lookup/scripting.sh"


#-Private-Functions-----------------------------#


# Prints the line of <file> immediately following the line containing only <string>.
# It is expected for there to be exactly one line containing only <string>.
# The line following the matched <string>-line must be non-empty.
#
# Arguments:
# * <string>
# * <in flag> possible values: "--in-string", "--in-file"
# * <file>
#
# Return status:
# 0: success
# 1: the given <in flag> was invalid
# 2: there were less or more than one line exactly matching <string> in <file>
function _line_after_unique_ {
   # Gets the line containing only <string> and the one following it and makes sure the <in flag>
   # was valid.
   case "$2" in
      --in-string) local -r match=$(egrep -A1 "^$1\$" <<< "$3") ;;
      --in-file)   local -r match=$(egrep -A1 "^$1\$" "$3") ;;
      *)           print_error_for --flag "$2"; return 1 ;;
   esac

   local -r matched_line_count=$(wc -l <<< "$match")

   # Returns on success if there was exaclty one match, or on failure otherwise.
   if [ "$matched_line_count" -eq 2 ]; then
      line_ 2 --in-string "$match"; return 0
   elif [ "$matched_line_count" -eq 0 ]; then
      print_error_for "Function matched no line for '$print_yellow$1$print_normal'."
   else
      print_error_for "Function matched multiple lines for '$print_yellow$1$print_normal'."
   fi

   # This point is only reached if not exactly one line matched <string>.
   return 2
}

# Prints all of the lines of <file> immediately following the line containing only <string> upto a
# certain delimiter.
# It is expected for there to be exactly one line containing only <string>.
# By default the delimiter is an empty line or EOF. If the "--until"-flag and a following
# <delimiter> are passed, all lines are printed upto the next line only containing <delimiter>.
#
# Arguments:
# * <string>
# * <in-file flag> possible values: "--in-file"
# * <file>
# or
# * <string>
# * <in-file flag> possible values: "--in-file"
# * <file>
# * <until flag> possible values: "--until"
# * <delimiter>
#
# Return status:
# 0: success
# 1: <in-file flag> or <until flag> was invalid
# 2: <delimiter> was not passed after <until flag>
# 3: there were less or more than one line exactly matching <string> in <file>
# 4: a custom <delimiter> was given, but never reached in <file>
function _lines_after_unique_ {
   # Makes sure the <in-file flag> was passed.
   [ "$2" = '--in-file' ] || { print_error_for --flag "$2"; return 1; }

   # If a flag was passed, makes sure it is valid and a delimiter was passed, or prints an error and
   # returns on failure. A flag is also set in the process, indicating whether a <flag> was passed.
   if [ -n "$4" ]; then
      # Asserts flag validity.
      [ "$4" != '--until' ] && { print_error_for --flag "$4"; return 1; }
      # Asserts delimiter validity.
      [ -z "$5" ] && { print_error_for "Function received no delimiter argument."; return 2; }
      local -r custom_delimiter=true
   else
      local -r custom_delimiter=false
   fi

   # Gets all of the lines in <file> exactly matching <string>.
   local -r match_line=$(egrep -n "^$1\$" "$3")

   # Makes sure that there was exactly one match line, or prints an error and returns on failure.
   if [ -z "$match_line" ]; then
      print_error_for "Function matched no line for '$print_yellow$1$print_normal'."
      return 3
   elif [ $(wc -l <<< "$match_line") -gt 1 ]; then
      print_error_for "Function matched multiple lines for '$print_yellow$1$print_normal'."
      return 3
   fi

   # Gets the line number immediately following the line of <string>'s match in <file>.
   local -r match_line_number=$(cut -d : -f 1 <<< "$match_line")
   local -r list_start=$((match_line_number + 1))

   # Prints all of the lines in <file> starting from "$list_start", until the delimiter line is
   # reached. If a custom delimiter is read, this is remembered by setting a flag.
   havent_read_custom_delimiter=true
   tail -n "+$list_start" "$3" | while IFS= read -r line; do
      if $custom_delimiter; then
         [ "$line" = "$5" ] && { havent_read_custom_delimiter=false; break; } || echo "$line"
      else
         [ -n "$line" ] && echo "$line" || break
      fi
   done

   # Makes sure a return on failure occurs if a custom delimiter was passed, but never read.
   $custom_delimiter && $havent_read_custom_delimiter && return 4

   return 0
}

# Prints the result of performing manual line continuation (on "\") in a given string.
#
# Arguments:
# * <string>
function _expand_line_continuations {
   # Iterates over the lines in the given string.
   while IFS= read -r line; do
      # If the last character in the line is "\", print neither it nor a trailing newline.
      [ "${line: -1}" = '\' ] && echo -ne "${line%?}" || echo -e "$line"
   done <<< "$1"

   return 0
}

# Replaces non-terminal symbols of a given regular expression file in a given regular expression.
#
# Arguments:
# * <regular expression file>
# * <in flag> possible values: "--in"
# * <regular expression>
#
# Return status:
# 0: success
# 1: the given <in flag> was invalid
# 2: <regular expression file> contains an improperly declared symbol
# 2: <regular expression file> contains an undefined
function _replace_symbols_of_ {
   # Makes sure the <in flag> was passed.
   [ "$2" != '--in' ] && { print_error_for --flag "$2"; return 1; }

   # Creates a working variable for the pattern and a symbol table for memoizing the regular
   # expressions of previously seen symbols.
   local raw_pattern=$3
   local symbol_table=''

   # Iterates as long as the raw pattern contains symbol delimiters.
   while [[ "$raw_pattern" == *!* ]]; do
      # Makes sure there are an even number of symbol delimiters.
      local symbol_delimiter_count=$(awk -F '!' '{print NF-1}' <<< "$raw_pattern")
      if [ $((symbol_delimiter_count % 2)) -eq 1 ]; then
         print_error_for "Regular expression '$print_yellow$3$print_normal' contains invalid" \
                         "symbol declaration."
         return 2
      fi

      # Gets the first symbol in the raw pattern.
      local first_symbol=$(cut -d '!' -f 2 <<< "$raw_pattern")
      local symbol_pattern

      # Tries to get the symbol pattern from the symbol table.
      symbol_pattern=$(
         silently- --stderr _line_after_unique_ "!$first_symbol!" --in-string "$symbol_table"
      )

      # Gets the symbol pattern from the regular expression file and memoizes it, if it was not
      # already memoized.
      if [ $? -ne 0 ]; then
         symbol_pattern=$(silently- --stderr _line_after_unique_ "!$first_symbol!" --in-file "$1")

         if [ $? -ne 0 ]; then
            print_error_for "Regular expression '$print_yellow$3$print_normal' contains undefined" \
                            "symbol '$print_yellow$first_symbol$print_normal'."
            return 3
         fi

         symbol_table=$symbol_table$'\n!'$first_symbol$'!\n'$symbol_pattern
      fi

      # Updates the raw pattern with the symbol's pattern.
      local sed_safe_symbol=$(sed_safe_ -s "!$first_symbol!")
      local sed_safe_symbol_pattern=$(sed_safe_ -r "$symbol_pattern")
      raw_pattern=$(sed -e "s/$sed_safe_symbol/$sed_safe_symbol_pattern/g" <<< "$raw_pattern")
   done

   # Prints the result and returns successfully.
   echo "$raw_pattern"
   return 0
}


#-Public-Functions------------------------------#


# Prints the column number of a given attribute in a given data file.
# All values are derived from a given file defaulting to <lookup file: data layout>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <layout file> passed automatically by the alias
# * <attribute>
# * <in flag>, possible values: "--in"
# * <data file identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: one or more of the given identifiers were invalid
# 2: <layout file> is malformed
alias column_for_="_column_for_ '$dot_lookup/../Lookup Files/data-layout' "
function _column_for_ {
   # Makes sure the <in flag> was passed.
   [ "$3" = '--in' ] || { print_error_for --flag "$3"; return 1; }

   # The string used to search the lookup file for attributes.
   local data_file_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$4" in
      static-index)   data_file_identifier='Static index:'          ;;
      static-config)  data_file_identifier='Static configuration:'  ;;
      runtime-index)  data_file_identifier='Runtime index:'         ;;
      runtime-config) data_file_identifier='Runtime configuration:' ;;
      rack-index)     data_file_identifier='Rack index:'            ;;
      rack-manifest)  data_file_identifier='Rack manifest:'         ;;
      *)              print_error_for --identifier "$4"; return 1   ;;
   esac

   # Gets the ordered list of attributes associated with the given data file, or returns on failure
   # if that operation fails.
   local data_file_attributes
   data_file_attributes=$(_lines_after_unique_ "$data_file_identifier" --in-file "$1") || return 2

   # Prints the relative line number, and thereby column number of the given attribute and returns
   # on success.
   local -i line_count=1
   while read -r data_file_attribute; do
      [ "$data_file_attribute" = "$2" ] && { echo $line_count; return 0; }
      ((line_count++))
   done <<< "$data_file_attributes"

   # This point is only reached if the given attribute is not associated with the given data file.
   print_error_for "Function received invalid attribute '$print_yellow$2$print_normal'."
   return 2
}

# Prints the URL associated with a given identifier, adapted to the current operating system.
# All URLs are taken from a given file defaulting to <lookup file: dependency urls>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <url file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <url file> does not contain <identifier>'s identifier-string
alias url_for_="_url_for_ '$dot_lookup/../Lookup Files/dependency-urls' "
function _url_for_ {
   # The string used to search the lookup file for a certain URL.
   local url_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      arduino-processing-lib) url_identifier='Arduino Processing library:' ;;
      standard-firmata-raw)   url_identifier='StandardFirmata raw:'        ;;
      ddfs-minim-lib)         url_identifier="ddf's Minim library:"        ;;
      arduino-cli)            url_identifier="Arduino-CLI $(current_OS_):" ;;
      processing)             url_identifier="Processing $(current_OS_):"  ;;
      *)                      print_error_for --identifier "$2"; return 1  ;;
   esac

   # Prints the line following the search string in the lookup file, or returns on failure if that
   # operation fails.
   _line_after_unique_ "$url_identifier" --in-file "$1" || return 2

   return 0
}

# Prints the constant string associated with a given identifier.
# All constants are taken from a given file defaulting to <lookup file: item names>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <item name file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <item name file> does not contain <identifier>'s identifier-string
alias name_for_="_name_for_ '$dot_lookup/../Lookup Files/item-names' "
function _name_for_ {
   # The string used to search the lookup file for a certain name.
   local name_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      arduino-cli)              name_identifier='Arduino-CLI:'                          ;;
      processing)               name_identifier='Processing:'                           ;;
      processing-executable)    name_identifier="Processing executable $(current_OS_):" ;;
      processing-lib-directory) name_identifier='Processing library directory:'         ;;
      arduino-processing-lib)   name_identifier='Arduino Processing library:'           ;;
      ddfs-minim-lib)           name_identifier="ddf's Minim library:"                  ;;
      arduino-uno-fbqn)         name_identifier='Arduino-UNO FQBN:'                     ;;
      rack-manifest-file)       name_identifier='Rack manifest file:'                   ;;
      config-read-cycle-trait)  name_identifier='Configuration read cycle trait:'       ;;
      *)                        print_error_for --identifier "$2"; return 1             ;;
   esac

   # Prints the line following the search string in the lookup file, or returns on failure if that
   # operation fails.
   _line_after_unique_ "$name_identifier" --in-file "$1" || return 2

   return 0
}

# Prints the path of the file/directory associated with a given identifier, adapted to the current
# operating system. There may be multiple paths printed, in which case they are on a seperate line
# each.
# All paths are taken from a given file defaulting to <lookup file: file paths>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <file locations file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <file locations file> does not contain <identifier>'s identifier-string
# TODO: Make relative paths absolute, by adding the repo-path to the lookup file with a tag?
alias path_for_="_path_for_ '$dot_lookup/../Lookup Files/file-paths' "
function _path_for_ {
   # The string used to search the lookup file for certain paths.
   local path_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      delete-with-install)     path_identifier='Delete with installation:'             ;;
      cli-command-source)      path_identifier='CLI-command source:'                   ;;

      lightshow-directory)     path_identifier='Lightshow program directory:'          ;;
      servers-directory)       path_identifier='Servers directory:'                    ;;
      firmata-directory)       path_identifier='StandardFirmata program directory:'    ;;

      static-index)            path_identifier='Static index:'                         ;;
      runtime-index)           path_identifier='Runtime index:'                        ;;
      rack-index)              path_identifier='Rack index:'                           ;;

      static-data-directory)   path_identifier='Static data directory:'                ;;
      runtime-data-directory)  path_identifier='Runtime data directory:'               ;;
      rack-data-directory)     path_identifier='Rack data directory:'                  ;;

      cli-command-destination) path_identifier='CLI-command destination:'              ;;
      arduino-cli-destination) path_identifier='Arduino-CLI destination:'              ;;
      app-directory)           path_identifier="Application directory $(current_OS_):" ;;
      downloads-directory)     path_identifier='Downloads directory:'                  ;;

      *)                       print_error_for --identifier "$2"; return 1             ;;
   esac

   # Gets the lines matched in the location-file for the given identifier, or returns on failure if
   # that operation fails.
   local -r raw_paths=$(_lines_after_unique_ "$path_identifier" --in-file "$1") || return 2

   # Performs explicit tilde expansion and prints the resulting paths.
   while read path; do
      [ "${path:0:1}" = '~' ] && echo "$HOME${path:1}" || echo "$path"
   done <<< "$raw_paths"

   return 0
}

# Prints the regular expression pattern associated with a given identifier.
# All patterns are taken from a given file defaulting to <lookup file: regular expressions>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <regular expression file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <regular expression file> does not contain <identifier>'s identifier-string
# 3: <regular expression file> contains an invalid symbol
alias regex_for_="_regex_for_ '$dot_lookup/../Lookup Files/regular-expressions' "
function _regex_for_ {
   # The string used to search the lookup file for a certain pattern.
   local regex_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      server-header)     regex_identifier='Server declaration header:'  ;;
      server-body)       regex_identifier='Server declaration body:'    ;;
      trait)             regex_identifier='Trait declaration:'          ;;
      number)            regex_identifier='Number:'                     ;;
      app-directory-tag) regex_identifier='Application directory tag:'  ;;
      int)               regex_identifier='Integer:'                    ;;
      float)             regex_identifier='Float:'                      ;;
      bool)              regex_identifier='Boolean:'                    ;;
      int-list)          regex_identifier='Integer-list:'               ;;
      float-list)        regex_identifier='Float-list:'                 ;;
      bool-list)         regex_identifier='Boolean-list:'               ;;
      *)                 print_error_for --identifier "$2"; return 1    ;;
   esac

   # Gets the line following the search string in the lookup file, or returns on failure if that
   # operation fails. This pattern might contain non-terminal symbols and is therefore "raw".
   local raw_pattern
   raw_pattern=$(_line_after_unique_ "$regex_identifier" --in-file "$1") || return 2
   # Gets the result of replacing all non-terminal symbols in the raw pattern, or returns on failure
   # if that operation failed
   local pattern; pattern=$(_replace_symbols_of_ "$1" --in "$raw_pattern") || return 3

   # Prints the result and returns successfully
   echo "$pattern"
   return 0
}

# Prints the text segment associated with a given identifier.
# All segments are taken from a given file defaulting to <lookup file: text segments>.
# The lookup file should only really be changed for testing purposes.
#
# Arguments:
# * <text segment file> passed automatically by the alias
# * <identifier>, possible values: *see below*
#
# Return status:
# 0: success
# 1: <identifier> is invalid
# 2: <text segment file> does not contain <identifier>'s identifier-string
alias text_for_="_text_for_ '$dot_lookup/../Lookup Files/text-segments' "
function _text_for_ {
   # The string used to search the lookup file for a certain segment.
   local segment_identifier

   # Sets the search string according to the given identifier, or prints an error and returns on
   # failure if an unknown identifier was passed.
   case "$2" in
      at-no-arduino)
         segment_identifier='arduino_trait.sh: No Arduino:' ;;
      at-multiple-arduinos)
         segment_identifier='arduino_trait.sh: Multiple Arduinos:' ;;
      wrii-header)
         segment_identifier='write_runtime_index_into.sh: Header:' ;;
      wrii-duplicate-instance-names)
         segment_identifier='write_runtime_index_into.sh: Duplicate instance names:' ;;
      wrii-invalid-server-names)
         segment_identifier='write_runtime_index_into.sh: Invalid server names:' ;;
      csi-header)
         segment_identifier='configure_server_instance.sh: Header:' ;;
      csi-invalid-trait-names)
         segment_identifier='configure_server_instance.sh: Invalid trait names:' ;;
      csi-duplicate-trait-names)
         segment_identifier='configure_server_instance.sh: Duplicate trait names:' ;;
      csi-invalid-trait-values)
         segment_identifier='configure_server_instance.sh: Invalid trait values:' ;;
      lightshow-usage)
         segment_identifier='lightshow: Usage:' ;;
      subcommand-live-usage)
         segment_identifier='lightshow: <live> subcommand usage:' ;;
      *)
         print_error_for --identifier "$2"; return 1 ;;
   esac

   # Gets the lines following the search string in the lookup file upto the line containing only
   # "SEGMENT-END", or returns on failure if that operation fails.
   if ! local -r text=$(
      _lines_after_unique_ "$segment_identifier" --in-file "$1" --until 'SEGMENT-END'
   )
   then
      return 2
   fi

   # Performs manual line continuation.
   local -r expanded_text=$(_expand_line_continuations "$text")

   # Substitutes color variables declared in <lookup file: text segments> for actual values and
   # prints the result.
   echo "$expanded_text" | sed \
      -e 's/RED>/\\033[0;31m/g' \
      -e 's/GREEN>/\\033[0;32m/g' \
      -e 's/YELLOW>/\\033[0;33m/g' \
      -e 's/NORMAL>/\\033[0;m/g'

   return 0
}
