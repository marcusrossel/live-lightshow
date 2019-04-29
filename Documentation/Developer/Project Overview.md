# Project Overview

This document contains a high-level overview of all of the components contained in the _Live Lightshow_ project and explains how they work and interconnect.

![Project Structure](https://github.com/marcusrossel/live-lightshow/tree/master/Documentation/Assets/Project%20Structure.png)

The project can roughly be split into three parts, responsible for different tasks:

1. **Proper Program:**
This part encompasses the files which contribute to running the actual program (started by `lightshow start`). It is limited to the _Program_ directory and is written in the _Processing_ language.

2. **User and Configuration Scripts:**
This part is responsible for almost all of the user-facing features of the project. It is mostly limited to the _Configuration_ and _Command Line Interface_ directories, with support from the _Utilities_ and _Lookup Files_ directories. This part is written in _Bash_.

3. **Supporting Files:**
This part consists of components required for enabling ease of use of the project. It is comprised of the _Installation_, _Tests_ and _Documentation_ directories.

## Proper Program

The proper program is split into three folders:

1. **_StandardFirmata:_**
This folder contains the program which will be loaded onto the _Arduino_ to allow serial communication with it. The program is downloaded and the folder created upon installation, and is therefore not present in the repository during development. The program is pushed onto the _Arduino_ whenever `lightshow initialize` is called.

2. **_Lightshow:_**
This folder contains the main components of the _Processing_-sketch which will be compiled and run upon `lightshow start`. `Lightshow.pde` is run first when the program starts. If is responsible for setting up a connection to the _Arduino_, creating configuration objects, instantiating servers, and capturing and feeding audio to the instances continuously. `Configuration.pde` defines the `Configuration` class, which is used by servers for accessing external configuration files. `Server.pde` defines the interface to which server-classes have to conform, in order to be usable with _Live Lightshow_.

3. **_Servers:_**
This folders contains the definitions (classes) of the servers, which can be used for a light show. During `lightshow start`, these files are temporarily copied to the _Lightshow_-folder to enable compilation. Server-classes have to have unqiue names, or else compilation will fail. Also, they can not have the names of any of the classes already defined in  the _Lightshow_ directory.

## User and Configuration Scripts

### _Lookup Files:_

To make scripting for this project as transparent and modular as possible, constant values are seperated out into _lookup files_. They arrange the constants in a structured format, so that it is discernable which purpose a constant serves. The constants can be attained from the files as is, but are easier to access by using the `lookup.sh` utility script. The purpose of each lookup file is described in the directory's [readme](https://github.com/marcusrossel/live-lightshow/blob/master/Lookup%20Files/README.md).


### _Utilities:_

The _Utilities_ directory contains the _Bash_-equivalent of libraries - so scripts that contain functions which can be imported in other scripts. Each library contains functions centered around a specific problem domain. So for example the scripts in the _Tests_ directory use the `testing.sh`-library, and the scipts concered with indexing use the `index.sh`-library. The purpose of each library is described in the directory's [readme](https://github.com/marcusrossel/live-lightshow/blob/master/Utilities/README.md).

### _Configuration:_

The _Configuration_ directory contains scripts, as well as configuration files. It can be split into of three parts:

1. **_Scripts:_**
This directory contains script focussed around creating static and runtime indices, as well as creating and editing configuration files.

2. **_Index:_**
This directory contains the _static-index_ and _runtime-index_.
The _static-index_ in created upon calling `lightshow initialize` or `lightshow reindex`. It contains information about which servers there are, what class names they have, whil file they are located in, and which static configuration file belongs to them.
The _runtime-index_ in created upon calling `lightshow start`, after the user specifies which server instances should be created. Its entries are only relevant for the currently running light show and it contains the server instances' names, their server types, as well as the name of their runtime configuration files.

3. **_Static_** and **_Runtime:_**
These folders contain the static and runtime configuration files associated with the servers and server instances specified in the _static-_ and _runtime-index_ respectively. Files in this directory are simply named by numbers in increasing order. The runtime configuration files can be edited by the user during runtime (in a constrained manner), but will always contain valid configurations.

### Command Line Interface

The _Command Line Interface_ directory contains scripts focussed around user-facing tasks. This for example includes things like starting a light show, and showing its status.
The main interface for accessing these scripts is the `lightshow` script, which is moved to a `$PATH`-directory upon installation. It usually simply provides a wrapper for scripts found in the CLI-directory.

## Supporting Files

The supporting files consist of three folders:

1. **_Installation:_**
This directory contains the scripts run by the user to install _Live Lightshow_. It is split into a script responsible for downloading dependencies, and one that moves all of the files to their proper destinations.

2. **_Tests:_**
This directory contains tests for other _Bash_-scripts in this project. The tests use the `testing.sh`-library to achieve a homogeneous output.

3. **_Documentation:_**
This directory contains documentation for user and developers of this project. More information can be found in the directory's [readme](https://github.com/marcusrossel/live-lightshow/blob/master/Documentation/README.md).
