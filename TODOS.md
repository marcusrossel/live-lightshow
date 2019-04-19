
---
### `Configuration.pde`:
* line 10: Make private.
* line 21: Factor this out, e.g. by automatically adding a trait to the static-traits in the static_index.sh
* line 24: Fatal error. */ }
* line 40: Fatal error. */ }
* line 7: Add documentation.
---
### `DefaultServer.pde`:
* line 1: Give Default Servers inertia.
* line 65: Clean this up.
* line 87: Figure out how to deal with non-Float traits.
---
### `DefaultVisualizer.pde`:
* line 1: Figure out how to handle visualizers.
---
### `Lightshow.pde`:
* line 1: Check these imports.
* line 2: Add documentation.
* line 68: Fatal error.
---
### `Server.pde`:
* line 2: For testing only.
* line 4: Figure out how to add a constructor or static method requirement.
---
### `coding-conventions.md`:
* line 1: Rewrite these.
---
### `configure_server_instance.sh`:
* line 88: Add proper error messages.
---
### `file-paths`:
* line 56: Find a location.
* line 62: Find a location.
---
### `index.sh`:
* line 84: Document this.
---
### `install.sh`:
* line 14: Also install vi if necessary.
* line 164: Remove the downloads folder as well.
* line 194: Hacky.
* line 231: Check if all of the commands are working and the tests pass.
* line 67: Make this properly global.
* line 98: Hacky.
---
### `lightshow`:
* line 44: Implement.
---
### `run_tests.sh`:
* line 6: Increase test-coverage.
---
### `start_lightshow.sh`:
* line 77: Make sure none of the servers are called "Server", "Configuration", or "Lightshow".
* line 85: Change this to `rm` when safe.
---
### `testing.sh`:
* line 125: Iron out the race conditions by having some kind of detection of input being read/expected.
---
### `write_runtime_index_into.sh`:
* line 68: Add proper error messages.
