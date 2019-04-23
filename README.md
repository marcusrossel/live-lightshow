# Live Lightshow

_Live Lightshow_ is a utility that allows you to transform your computer's audio input into a corresponding visual output through an _Arduino UNO_.  
As a user you can easily configure your own custom light show. And as a developer you can create new light show components and make them available to other users.

## Requirements

This program runs as a command line utility, so you will have to be able to perform basic operations in a terminal. For a quick overview check out the [Terminal Basics](https://github.com/marcusrossel/live-lightshow/blob/master/Documentation/User/Terminal%20Basics.md) guide.

Supported operating systems are _Windows 10_, _macOS_ and _Linux_ distributions. If you are running _Windows 10_ you need to use this program from the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

Following command line utilities are required:
* [curl](https://curl.haxx.se/dlwiz/?type=bin) for installation
* [bash](https://www.gnu.org/software/bash/) for running the program
* [vi](https://www.vim.org/download.php) for configuring a light show

If you are missing any of these utilities, please install them. You can check whether they are installed by running:  

```bash
for u in curl bash vi; do command -v $u &>/dev/null || echo $u is missing; done
```

## Installation
To install the _Live Lightshow_ you first need to download and unzip the [newest release](???). To install the program, navigate to the unzipped folder in a terminal and run `Installation/install.sh`.

The installer might ask you for your password along the way. If you would like to know why you need to provide it, check [Why my password?](???) for details.

After completing the installation process, the _Live Lightshow_ will be accessible using the `lightshow` command.


## Using _Live Lightshow_

_Live Lightshow_ requires you to know a couple of simple concepts to get the most out of this utility. To learn about how to use _Live Lightshow_, check out the following guides:

* [Getting Started](https://github.com/marcusrossel/live-lightshow/blob/master/Documentation/User/Getting%20Started.md)
* [Creating Presets](???)
* [Developing a Server](???)
