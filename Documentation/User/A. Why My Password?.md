# Why My Password?

The installation of _Live Lightshow_ might require you to enter your computer's password in the process. The reason for this is that the installer needs to move two command line utilities into system-protected folders. More specifically, it will move `arduino-cli` and `lightshow` into the `/usr/local/bin` directory and on _Linux_ (and therefore _Windows_) the supporting files into `/usr/local`. This is done so that you can call `lightshow` from anywhere on your computer, and don't have to refer to the script-file itself everytime.
The specific command asking for your password is `sudo`. You can search for `sudo` in the [installer-script's source](Installation/install.sh) to see what it is used for.

---

| [← Documentation Overview](..) | [B. Capturing System Audio on macOS →](B.%20Capturing%20System%20Audio%20on%20macOS.md) |
| - | - |
