import java.util.*;
import java.util.stream.Collectors;
import java.util.Random;
import processing.serial.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import cc.arduino.*;

//-------------------------------------------------------------------//
// CLASSES
//-------------------------------------------------------------------//


// The configuration contains an initial condition.
// This is read via threshold_configuration.sh and put into the config file, before the lightshow runs (when calling `lightshow start`).
// The parameters are then periodically read by this class while the lightshow is running.
// Upon exiting the user can choose if they want to keep the current configuration, in which case it is hardcoded into this class again via `apply_configuration.sh`. (Should be doable by calling the shell script from stop()).
// This way developers can easily add new configuration-parameters.

// This could also be usefull for monitoring values, by adding non-const values, which get set
// (manually) within the program.
class Configuration {
   Configuration(String filePath) {
      this.filePath = filePath;
      this.runtimeValues = HashMap<String, Integer>();
      updateFromConfigFile();
   }

   String filePath;

   // If this is accessed, and the update cycle has passed... only then read from the file.
   // Probably needs a getter-function to realize this behaviour.
   HashMap<String, Integer> runtimeValues;

   void updateFromConfigFile() {
      // TODO

   }

   // Initial values:

   // #threshold "Configuration Update Cycle"
   const int seconds = 3;

   // #threshold "Something"
   const int something = 1;

   // #threshold "Else"
   const int other = 2;

   //...

   // #threshold-declarations-end
}


//-------------------------------------------------------------------//
// GLOBAL OBJECTS
//-------------------------------------------------------------------//


Arduino arduino;
Minim minim;
AudioInput input;
FFT fft;
ArrayList<BandDescriptor> bandDescriptors;
Visualizer visualizer;


//-------------------------------------------------------------------//
// SETUP
//-------------------------------------------------------------------//


void setup() {
  // Sets the window size.
  size(1280, 720, P3D);

  // Initializes the non-native objects.
  minim = new Minim(this);
  input = minim.getLineIn();
  fft = new FFT(input.bufferSize(), input.sampleRate());

  String arduinoPath = "";
  String configFilePath = "";
  if (args != null && args.length == 2) {
    arduinoPath = args[0];
    configFilePath = args[1];
  } else {
    System.err.println("Error: Expected <arduino device path> <configuration file> as parameters");
    exit();
  }

  arduino = new Arduino(this, arduinoPath, 57600);

  // Initializes the band descriptors.
  bandDescriptors = new ArrayList<BandDescriptor>(Arrays.asList(
    new BandDescriptor(30f, 300f, new ArrayList<Integer>(Arrays.asList(2, 3, 4)), 2f),
    new BandDescriptor(300f, 4000f, new ArrayList<Integer>(Arrays.asList(5, 6, 7)), 4f),
    new BandDescriptor(4000f, 16000f, new ArrayList<Integer>(Arrays.asList(8, 9, 10)), 5f)
   ));

  // Initializes the visualizer.
  visualizer = new Visualizer(bandDescriptors);

  // Initializes the Arduino's pins.
  for (BandDescriptor bandDescriptor : bandDescriptors) {
    for (Integer pin : bandDescriptor.outputPins) {
      arduino.pinMode(pin, Arduino.OUTPUT);
    }
  }
}


//-------------------------------------------------------------------//
// TEARDOWN
//-------------------------------------------------------------------//


void stop() {
  input.close();
  minim.stop();
  super.stop();
}


//-------------------------------------------------------------------//
// MAIN
//-------------------------------------------------------------------//

void draw() {
  background(0);

  fft.forward(input.mix);
  for (BandDescriptor descriptor : bandDescriptors) {
    descriptor.processCurrentFrame(fft);
  }
  visualizer.visualizeWaveformForFrame(input.mix);
  visualizer.visualizeDescriptorParameters();
  visualizer.visualizeSpectrumForFrame(fft, true);
}
