#!/bin/bash

# This script downloads the all of the dependencies needed for this project to run and places them
# in a given directory (which can not exist before).
#
# Arguments
# <downloads' directory>
#
# Return status:
# 0: success
# 1: invalid number of command line arguments
# 2: a download failed
# 3: a download had unexpected format


#-Preliminaries---------------------------------#


# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports lookup and utilities.
. "$_dot/../Scripts/Utilities/lookup.sh"
. "$_dot/../Scripts/Utilities/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"


#-Constants-------------------------------------#


# The function wrapping all constant-declarations for this script.
function declare_constants {
   # Records the current directory, to return to it later.
   readonly previous_working_directory=$PWD
   # Binds the command line argument.
   readonly downloads_destination=$1

   # Creates a working directory for the downloader.
   readonly working_directory=$(mktemp -d)

   return 0
}


#-Functions-------------------------------------#


# Downloads an archive containing only a single file/directory, renames it and places it in the
# current working directory.
#
# Arguments:
# * <dependency url identifier>
# * <item name identifier> optional, defaults to <dependency url identifier>
#
# Return status:
# 0: success
# 1: could not download from URL associated with <dependency url identifier>
# 2: the downloaded item has the wrong format
function download_single_item_archive_ {
   # Captures the command line arguments.
   local -r url_identifier=$1
   [ -n "$2" ] && local -r name_identifier=$2 || local -r name_identifier="$url_identifier"

   # Gets/sets string constants.
   local -r item_url=$(url_for_ "$url_identifier")
   local -r item_folder='single_item_folder'

   # Downloads the item.
   if ! curl -Lk --progress-bar -o "$item_folder.zip" "$item_url"; then
      echo "Error: failed to download from \"$item_url\"" >&2
      return 1
   fi

   # Unzips and removes the archive.
   silently- unzip "$item_folder.zip" -d "$item_folder"
   rm "$item_folder.zip"

   # Makes sure the downloaded archive has the expected format, or prints and error message and
   # returns on failure.
   if [ $(wc -l <<< $(ls "$item_folder")) -ne 1 ]; then
      echo "Error: Downloaded archive has unexpected format" >&2
      return 2
   fi

   # Renames the item, moves it to the working directory and deletes its folder.
   local -r item_name=$(name_for_ "$name_identifier")
   mv "$item_folder"/* "$working_directory/$item_name"
   rm -r "$item_folder"
}

# Downloads the standard firmata raw program, captures it in a file and places it in an
# appropriately named directory in the working directory.

# Return status:
# 0: success
# 1: could not download from URL associated with <dependency url identifier>
function download_standard_firmata_ {
   local -r raw_file_url=$(url_for_ standard-firmata-raw)
   local -r program_directory=$(basename "$(path_for_ firmata-directory)")
   local -r file_name="$program_directory.ino"


   if ! curl -Lk --progress-bar "$raw_file_url" >"$file_name"; then
      echo "Error: failed to download from \"$item_url\"" >&2
      exit 1
   fi

   mkdir "$program_directory"
   mv "$file_name" "$program_directory"

   return 0
}


#-Main------------------------------------------#


assert_correct_argument_count_ 1 "<downloads' directory>" || exit 1
declare_constants "$@"

# Moves to the working directory and makes sure everythin is cleaned up upon exiting.
cd "$working_directory"
trap "silently- rm -r '$working_directory'; cd '$previous_working_directory'" EXIT

# Downloads all of the dependencies that are single item archives.
for dependency in arduino-cli processing arduino-processing-lib ddfs-minim-lib; do
   download_single_item_archive_ $dependency || exit $(($?+1))
done;

# Downloads the StandardFirmata program and places it in an appropriate folder.
download_standard_firmata_ || exit $(($?+1))

# Moves all of the downloaded items to the <downloads' directory> (while creating that folder).
mv "$working_directory" "$downloads_destination"

exit 0
