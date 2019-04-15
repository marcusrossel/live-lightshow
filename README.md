# Live Lightshow

_Live Lightshow_ is a utility that allows you to transform your computer's audio input into a corresponding visual output through an Arduino.  
The setup currently only supports the [Arduino UNO](https://store.arduino.cc/arduino-uno-rev3).

---

## Installation
To install the _Live Lightshow_, run the following command in a terminal:  
```bash
curl 'https://raw.githubusercontent.com/marcusrossel/live-lightshow/master/Installer/installer.sh' | bash
```

If you can't find your local terminal application, reference the following:
* _macOS_: [how to open a terminal](https://www.wikihow.com/Open-a-Terminal-Window-in-Mac)
* _Linux_: [how to open a terminal](https://www.lifewire.com/ways-to-open-a-terminal-console-window-using-ubuntu-4075024)
* _Windows 10_: requires that you install the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-win10)

If the command `curl` is not found, please [install it](https://curl.haxx.se/dlwiz/?type=bin).

## Setup
The _Live Lightshow_ can be configured to output to as many LEDs as you need, or even run custom code instead of producing regular output.  

For a basic setup, refer to the [Basic Setup Guide](https://github.com/marcusrossel/live-lightshow/tree/master/Documentation/Basic%20Setup%20Guide).  
If you want to customize you setup, refer to the [Setup Customization Guide](https://github.com/marcusrossel/live-lightshow/tree/master/Documentation/Setup%20Customization%20Guide).

## Starting a Light Show
If you have not used _Live Lightshow_ before, or loaded a different program onto your Arduino between uses, call `lightshow initialize`.
You can then start a light show by calling `lightshow start`.
