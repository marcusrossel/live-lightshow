# Coding Conventions

This file contains descriptions of certain coding conventions used in the Command Line Interface's
scripts.

---

## File Structure
Scripts, except for [pseudo-libraries](#pseudolibraries) and tests, are structured into:
* preliminaries
* constant declarations
* function declarations
* the main script

#### Preliminaries:
The preliminaries section contains imports of [pseudo-libraries](#pseudolibraries) and the
declaration of the `dot` variable. The `dot` variable contains the path to the script file in which
it is declared (the name _dot_ is therefore chosen to resemble the `.` used to refer to the current
directory). This is useful when referring to other paths, based on the location of the script. If
`dot` is used after an import it should be reset, as it might have been overwritten during the
import.

#### Constants:
Constants are declared in a `declare_constants` function which expects all of the script's command
line arguments as parameters. `declare_constants` is the first function (after
`assert_correct_argument_count_`) to be called in the main script. This way constant declarations
can also use functions declared after the `declare_constants` function itself. Constant declarations
use `readonly` instead of `declare -r`, so that the declarations are global. The `declare_constants`
may be failable.

#### Functions:
Functions are declared with the `function` keyword. Leading and trailing underscores in functions'
names have semantic relevance, as described in [pseudo-libraries](#pseudolibraries) and
[error handeling](#errorhandeling). Functions are preceded by documentation containing expected
arguments and output (and return status if they are failable).

<a name="main"></a>
#### Main:
The main section of the script contains the equivalent of a `main`-function in other languages. It
starts by calling `declare_constants` if appropriate. It is also resposible for propagating any
failing return status produced by calling failable functions.

---

<a name="errorhandeling"></a>
## Error Handeling

#### Functions:
Functions whose names end on an underscore can fail, indicated by returning on a non-zero or
"failing" return status. Functions without a trailing underscore should be expected to succeed and
return `0`. Functions whose name end on a hyphen reflect the return status of a given command, and
are therefore failable if and only if the given command is failable.

#### Main:
Return statuses of scripts are solely determined by calls to `exit` in the [main section](#main) of
a script. Functions can therefore `return` but never `exit`. The return status of a script can be
the result of a failing return status of a function. The function's own return is decoupled from the
script's return statuses though. The mapping of functions' to scripts' return statuses is performed
manually. Any return status in an `exit` is incremented by the highest previously used return
status. To make this more easily trackable, any call to `exit` is annotated with a comment of the
form: `#RS+<addition>=<new>`. Here `<addition>` is the highest used return status of the previous
failable function and `<new>` is the new highest return status. The form `#RS=<new>` (where `<new>`
is greater that the previous `RS`) is used when the previous failable function's return status is
not used.

---

<a name="pseudolibraries"></a>
## Pseudo-Libraries
Certain functions are used across multiple scripts. These functions live in "libraries", which are
simply scripts containing only function and alias declarations. These libraries are imported by
sourcing the execution of the script (`source <library>`/`. <library>`).
Libraries are layed out slightly differently than other script files. Constants are not declared in
a seperate function, and constants not meant for use outside of the script are preceded by an
underscore in there name. Certain functions in libraries have convenience-aliases meant to be used to call the given function. Such functions are denoted by a leading underscore in their name, and their corresponding alias is declared right above the function declaration.

---

## Variable Declarations
Variables are declared as _readonly_ whenever possible. For global variables this implies the use of
the `readonly` keyword, for local variables the `-r` flag is set. Variables within functions are
always declared as _local_. Assignments of the value of a process substitution of a failable
function whose return status is not ignored, can not be made _readonly_, as `local` and `readonly`
do not propagate the return status of the assignment.
