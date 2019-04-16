#!/bin/bash

# This script serves as a library of functions to be used by the CLI's test-scripts. It can be
# "imported" via sourcing.
# It should be noted that this script activates alias expansion.


#-Preliminaries---------------------------------#


# Sets up an include guard.
[ -z "$CLI_TESTING_UTILITIES_INCLUDED" ] && readonly CLI_TESTING_UTILITIES_INCLUDED=true || return

# Gets the directory of this script.
_dot=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Imports the CLI-utilities.
. "$_dot/../Libraries/utilities.sh"
# (Re)sets the dot-variable after imports.
dot="$_dot"

# Turns on alias-expansion explicitly as users of this script will probably be non-interactive
# shells.
shopt -s expand_aliases


#-Functions-------------------------------------#


# Prints a description about whether the test with a given identifier succeeded based on whether the
# last return status corresponds to an expected value or not.
# If a "--conditional"-flag is passed, the ouput is printed in yellow, to signify that it should not
# be taken at face value.
#
# Arguments:
# * <test-identifier> passed automatically as the current line number by the alias
# * <flag> optional, possible values: "--conditional"
# * <expected return status>
# * <last return status> optional, is set as $? if not passed explicitly
alias report_if_last_status_was='_report_if_last_status_was "Line $LINENO" '
function _report_if_last_status_was {
   # Secures the last return status.
   local return_status=$?

   # Sets a flag indicating whether the "--conditional"-flag was passed.
   [ "$2" = '--conditional' ] && local -r is_conditional=true || local -r is_conditional=false

   # Captures the function's arguments and printing color differently, depending on whether the
   # "--conditional"-flag was passed.
   if $is_conditional; then
      [ -n "$4" ] && return_status=$4
      local -r expected_return_status=$3
      local -r ok_color=$print_yellow; local -r bad_color=$print_yellow;
   else
      [ -n "$3" ] && return_status=$3
      local -r expected_return_status=$2
      local -r ok_color=$print_green; local -r bad_color=$print_red;
   fi

   # Prints a message depending on whether <last return status> has the expected value or not.
   if [ "$return_status" -eq "$expected_return_status" ]; then
      echo -e "◦ $ok_color$1\tOK$print_normal"
   else
      echo -ne "◦ $bad_color$1\tNO: Expected return status $expected_return_status, "
      echo -e  "but got $return_status$print_normal"
   fi

   return 0
}

# Prints a description about whether a given output string matches a given expected string. The use
# of this functions implies and expectation that the last return status was 0. If this is not the
# case this is also reported.
# The comparison is performed numerically if the "--numeric"-flag is passed.
#
# Arguments:
# * <last return status> passed automatically as $? by the alias
# * <test-identifier> passed automatically as the current line number by the alias
# * <flag> optional, possible values: "--numeric"
# * <output string>
# * <expected output string>
alias report_if_output_matches='_report_if_output_matches $? "Line $LINENO" '
function _report_if_output_matches {
   # Secures the last return status.
   local -r return_status=$1

   # Determines whether the ouput matches according to whether the "--numeric" <flag> was set.
   if [ "$3" = --numeric ]; then
      [ "$4" -eq "$5" ] && local -r output_matches=true || local -r output_matches=false
   else
      [ "$3" = "$4" ] && local -r output_matches=true || local -r output_matches=false
   fi

   # Makes sure that the last return status was not failing, or else reports this and returns.
   [ "$return_status" -eq 0 ] || { _report_if_last_status_was "$2" 0 "$return_status"; return 0; }

   # Prints a message depending on whether the output matched or not (as determined above).
   if $output_matches; then
      echo -e "◦ $print_green$2\tOK$print_normal"
   else
      echo -e "◦ $print_red$2\tNO: Expected different output$print_normal"
   fi

   return 0
}

# This function is used to write to stdin and read from stdout of a given command, while it is
# running. This means that commands expecting input from stdin can be used programmatically.
#
# The command (now called "target") and its arguments are simply passed simply as arguments to this
# function. The commands meant to interact with the target (now called "actions"), are to be passed
# via stdin.
# The actions are run in an environment where their stdout writes to the target's stdin and vice
# versa. This allows the actions to read from and write to the target.
# Output by the target which was not read by the actions, is printed to this functions stdout, once
# the actions have finished running. This does not necessarily mean that the target has finished
# running at that time.
#
# The function will always run in a subshell.
#
# Arguments:
# * <target command>
# * <action commands> via stdin
#
# Return status:
# $? of <command>
#
# TODO: Iron out the race conditions by having some kind of detection of input being read/expected.
function interactively- { ( _interactively- "$@" ); }
function _interactively- {
   # Overwrites the EXIT trap so that the 'commands_for_trap_with_signal_' command works properly.
   # This is because: https://lists.gnu.org/archive/html/info-gnu/2011-02/msg00012.html
   # This function is assured to be running in a subshell.
   trap - EXIT

   # Creates the directory in which the named pipes will live.
   local -r pipe_directory=`mktemp -d`

   # Adds the removal of the pipe directory to the EXIT trap.
   trap "rm -r \"$pipe_directory\"" EXIT

   # Creates the named pipes which will redirect the interactive commands' stdout to <command>'s
   # stdin and vice versa.
   local -r command_stdin="$pipe_directory/command_stdin"
   local -r command_stdout="$pipe_directory/command_stdout"
   mkfifo "$command_stdin"
   mkfifo "$command_stdout"

   # Calls the command as background process using the named pipes for redirection and secures its
   # PID.
   "$@" <"$command_stdin" >"$command_stdout" &
   local -r command_pid="$!"

   # Adds the killing of <command>'s process as cleanup step to the EXIT trap.
   local -r process_cleanup="ps -p $command_pid &>/dev/null && kill -TERM $command_pid"
   trap "$process_cleanup; `commands_for_trap_with_signal_ EXIT`" EXIT

   # Checks if there is any input on stdin, and gets all of the interactive commands by reading it,
   # if there is any.
   # The method of doing this is dependant on the Bash version running.
   if [ "${BASH_VERSINFO[0]}" -gt 3 ]; then
      read -t 0 && local -r interactive_commands=`cat`
   else
      if read -t 1; then
         local -r newline=$'\n'
         local -r interactive_commands="$REPLY$newline`cat`"
      fi
   fi

   # Runs the interactive commands (if there are any) in an environment where stdout writes to
   # <command>'s stdin and <command>'s stdout writes to stdin.
   # If is important that this point in the funtion is reached, as this unblocks <command> by
   # completing the connection of the named pipes.
   {
      [ -n "$interactive_commands" ] || return
      eval "$interactive_commands"
   } >"$command_stdin" <"$command_stdout"

   # Prints unread output of <command> to stdout.
   cat <"$command_stdout"

   # Waits for <command> to finish running and returns with the <command>'s return status.
   wait $command_pid
   return $?
}
