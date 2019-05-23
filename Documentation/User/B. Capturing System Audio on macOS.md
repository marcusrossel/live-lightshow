# Capturing System Audio on _macOS_

## 1. Installing _Soundflower_

_Soundflower_ is a utility which allows you to create audio devices for rerouting audio in _macOS_.  
You can download its disk image from [_mattingalls_' release on _GitHub_](https://github.com/mattingalls/Soundflower/releases/download/2.0b2/Soundflower-2.0b2.dmg) and simply follow the installer's instructions. For more details checkout the [repository page](https://github.com/mattingalls/Soundflower/releases/tag/2.0b2).

Once _Soundflower_ is installed, open your system's _Sound_ settings. The _Input_ and _Output_ panels should now each contain entries called `Soundflower (2ch)` and `Soundflower (64ch)`.

## 2. Creating a Multi Output Device

If you currently select either of the _Soundflower_-devices for your audio output, you will notice that you can't actually hear any of the audio. This is because none of the audio signals are being sent to any real output device - but are rather being redirected to be audo input.  
To still be able to hear the audio that is being captured by _Soundflower_, you need to create a special audio device.

To achieve this, open the _Audio-MIDI-Setup_ utility that comes preinstalled on your _mac_:

![Audio-MIDI-Setup Logo](../Assets/Audio-MIDI-Setup%20Logo.png)

In _Audio-MIDI-Setup_ hit the `+` button at the bottom left corner and select `Create Multi Output Device`. In the the panel that appears on the right, select `Built-in Output` and `Soundflower (2ch)`.  
This new audio device will capture your computer's system audio while still playing it through your built-in audio output. If you want a device that only captures your system audio but does not play it out loud, unselect the `Builtin-Ouput`.

## 3. Configuring Sound Settings

Now that you have setup a multi output device, you can play audio and capture it at the same time. This now simply requires a little bit of setup in the _Sound_ settings.  
In the _Output_ panel, select the multi output device you have just created.  
In the _Input_ panel, select `Soundflower (2ch)`.

If you now play some audio, you should see the _Input_-panel's _Input level_-meter show a response.

