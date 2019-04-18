#!/bin/bash

# This script prints a template for the user to choose which server-instances should be created at
# runtime.
#
# Arguments:
# * <server ID-class map> optional, for testing purposes
#
# Return status:
# 0: success
# 1: invalid number of arguments


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports lookup and utilities.
. "$_dot/../Utilities/lookup.sh"
. "$_dot/../Utilities/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   # Sets the location of the <server ID-class map> as the first command line argument, or to the
   # one specified by <lookup file: file paths> if none was passed.
   if [ -n "$1" ]; then
      readonly server_id_class_map=$1
   else
      readonly server_id_class_map="$dot/../../$(path_for_ server-id-class-map)"
   fi
}


#-Main------------------------------------------#


assert_correct_argument_count_ 0 1 '<server ID-class map: optional>' || exit 1
declare_constants "$@"

cat << END
# Declare which types of servers you want to use for the lightshow.
# You can have multiple instances of the same server type.
#
# Each declaration should have the form:
# <unique identifier>: <server type>
#
# So for example one declaration could be:
# Example Identifier: example-server-type
#
# The <unique identifier>s may not contain the characters " and : and may not appear more than once.
# Possible <server type>s are:
END

# Prints the server-identifiers contained in <server ID-class map> in the form:
# # * <id 1>
# # * <id 2>
# ...
while read id_class_entry; do
   echo "# * $(cut -d : -f 1 <<< "$id_class_entry")"
done < "$server_id_class_map";
