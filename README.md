# Live Lightshow
![Release Version](https://img.shields.io/badge/release-v0.1-red.svg) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0) ![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows%2010-lightgrey.svg)

_Live Lightshow_ is a utility that allows you to transform your computer's audio input into a corresponding visual output through an _Arduino_.  
As a user you can easily configure your own custom light show. And as a developer you can create new light show components and make them available to other users.

## Why Use _Live Lightshow_?

_Live Lightshow_ removes all of the overhead required to create your own _Arduino_-based audio-visualizer.  
As a non-developer it gives you the freedom to setup and perform in-depth configuration of a light show, without writing a single line of code.  
As a developer it allows you to create a custom audio-visualizer and make it customizable by other users, all within a single code file (cf. [Developing a Server](Documentation/Developer/2.%20Developing%20a%20Server.md)).  
And as a benefit to both users and developers, _Live Lightshow_ encourages collaboration by design - for example by natively supporting the integration of other peoples' audio-visualizers.

Sofar _Live Lightshow_ has been used successfully at an event of [Sektor Evolution](https://www.facebook.com/events/456772748390695/), and will be used for the [Treibsand Open Air](https://www.facebook.com/Treibsand-Freiland-Open-Air-163226903787990/) later this year.

## Requirements

Only *Arduino*-boards with an *AVR*-core are supported. This includes *Arduino*s like the _UNO_ and _MEGA_.

This program runs as a command line utility, so you will have to be able to perform basic operations in a terminal. For a quick introduction check out the [Terminal Basics](Documentation/User/1.%20Terminal%20Basics.md) guide.

Supported operating systems are _Windows 10_, _macOS_ and _Linux_ distributions. If you are running _Windows 10_ you need to use this program from the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

Following command line utilities are required:
* [curl](https://curl.haxx.se/dlwiz/?type=bin) for installation
* [bash](https://www.gnu.org/software/bash/) for running the program
* [vi](https://www.vim.org/download.php) for configuring a light show

If you are missing any of these utilities, please install them. Running the following script, will tell you if any are missing:  

```bash
for u in curl bash vi; do command -v $u &>/dev/null || echo $u is missing; done
```

## Installation
To install the _Live Lightshow_ you first need to download and unzip its [newest release](https://github.com/marcusrossel/live-lightshow/releases/tag/v0.1-alpha). Then navigate to the unzipped folder in a terminal and run `Installation/install.sh`.

The installer might ask you for your password along the way. Check out [Why my password?](Documentation/User/2.%20Why%20My%20Password%3F.md) for details about this.

After completing the installation process, the _Live Lightshow_ will be accessible using the `lightshow` command - so you can delete the downloaded folder if you like.


## Using _Live Lightshow_

_Live Lightshow_ requires you to know a couple of simple concepts to get the most out of this utility. To learn about how to use and/or develop for it, check out the [Documentation](Documentation) containing guides like:

* [Getting Started](Documentation/User/2.%20Getting%20Started.md)
* [Setup Example](Documentation/User/4.%20Setup%20Example.md)
* [Developing a Server](Documentation/Developer/2.%20Developing%20a%20Server.md)
* [Contributing](Documentation/Developer/5.%20Contributing.md)

---

This project is licensed under the _GPLv3_, so feel free to clone and modify it to your heart's content.
