#!/bin/bash

# This script serves as a library of functions for dealing with trait value types. It can be
# "imported" via sourcing.
# It should be noted that this script activates alias expansion.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$TYPES_SH" ] && readonly TYPES_SH=true || return

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases

# Gets the directory of this script.
dot_index=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports scripting and lookup utilities.
. "$dot_index/scripting.sh"
. "$dot_index/lookup.sh"


#-Functions-------------------------------------#


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
