#!/bin/bash

# This script scans the given instance-type map and generates the configuration files for each
# instance at a given location, by scanning given program files for trait-declarations. It prints
# the resulting instance-configuration-file map when complete.
#
# An instance-configuration-file map consists of entries of the form:
# <instance 1 ID>: <repo-relative configuration file path 1>
# <instance 2 ID>: <repo-relative configuration file path 2>
# ...
#
# Arguments:
# * <program files> optional, for testing purposes
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


#-Functions-------------------------------------#
