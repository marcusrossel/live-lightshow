// This file contains the `setup` and `loop` methods for Live Lightshow.
//
// As setup it creates the AudioInput and FFT objects used to capture audio and creates an Arduino object.
// It also instantiates the configuration objects and server instances as defined by a given server instantiation map.
//
// Running this program requires the following arguments:
// * <arduino path>: a file path to the device-file of an Arduino
// * <server instantiation map>: a string of the form:
//     <class name 1>:<static configuration file 1>:<runtime configuration file 1>
//     <class name 2>:<static configuration file 2>:<runtime configuration file 2>
//     ...


//-IMPORTS-----------------------------------------------------------//


import java.util.*;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.lang.reflect.Constructor;
import ddf.minim.*;
import ddf.minim.analysis.*;
import processing.serial.*;
import cc.arduino.*;


//-GLOBAL-OBJECTS----------------------------------------------------//


Minim minim;
AudioInput lineIn;
FFT fft;
List<Server> servers;


//-FUNCTIONS---------------------------------------------------------//


// Returns a the list of servers as declared by a given server instantiation map.
// The given list may only contain server classes which are defined and valid configuration file paths - or else an exception will be thrown.
List<Server> serversForInstantiationMap(String serverInstantiationMap, Arduino arduino) throws Exception {
   // The container for the servers to be instatiated.
  List<Server> instantiatees = new ArrayList<Server>();

  // Iterates over the server instantiation map entry for each expected server instance.
  Scanner mapScanner = new Scanner(serverInstantiationMap);
  while (mapScanner.hasNextLine()) {
    // Gets the map entry.
    String mapEntry = mapScanner.nextLine();
    String[] entryComponents = mapEntry.split(":");

    // Gets the map entry components as their respective types.
    // The class name must be preceeded by "Lightshow$", presumably because that is the enclosing class for this sketch.
    Class instanceClass = Class.forName("Lightshow$" + entryComponents[0]);
    Path staticConfiguration = Paths.get(entryComponents[1]);
    Path runtimeConfiguration = Paths.get(entryComponents[2]);

    // Creates the instance's configuration and constructor.
    // The constructor implicitly requires a `Lightshow` object as first argument.
    Configuration configuration = new Configuration(staticConfiguration, runtimeConfiguration);
    Constructor instanceConstructor = instanceClass.getConstructor(Lightshow.class, Configuration.class, Arduino.class);

    // Instantiates the instance and adds it to the list of servers.
    Server instance = (Server) instanceConstructor.newInstance(this, configuration, arduino);
    instantiatees.add(instance);
  }

  mapScanner.close();
  return instantiatees;
}


//-SETUP-------------------------------------------------------------//


void setup() {
  // Makes sure no window is shown.
  // The `fullScreen` method is called before setting the window as invisible, because it will briefly pop up anyway and so it looks better if fullscreened first.
  fullScreen();
  surface.setVisible(false);

  // Creates the objects required to capture audio.
  minim = new Minim(this);
  lineIn = minim.getLineIn();
  fft = new FFT(lineIn.bufferSize(), lineIn.sampleRate());

  // Creates the variables for the command line arguments.
  String arduinoPath = "";
  String serverInstantiationMap = "";

  // Binds the command line arguments to their variables, or aborts the program if that is not possible.
  if (args != null && args.length == 2) {
    arduinoPath = args[0];
    serverInstantiationMap = args[1];
  } else {
    println("Internal error: `Lightshow.pde` didn't receive the correct number of command line arguments");
    System.exit(1);
  }

  // Creates the Arduino object from the given device-path and initializes all digital pins to be outputs.
  // This could technically be done in the server instances, or with delegate methods - but this is simpler for now.
  Arduino arduino = new Arduino(this, arduinoPath, 57600);
  for (Integer pin = 2; pin <= 13; pin++) {
    arduino.pinMode(pin, Arduino.OUTPUT);
  }

  // Instantiates and captures the server instances or aborts if that operation fails.
  try {
    servers = serversForInstantiationMap(serverInstantiationMap, arduino);
  } catch (Exception e) {
    println("Internal error: `Lightshow.pde` was unable to instantiate servers");
    System.exit(2);
  }
}


//-TEARDOWN----------------------------------------------------------//


void stop() {
  lineIn.close();
  minim.stop();
  super.stop();
}


//-RUN-LOOP----------------------------------------------------------//


void draw() {
  // Gets the next audio chunk from the line-in and FFTs it.
  AudioBuffer chunk = lineIn.mix;
  fft.forward(chunk);

  // Passes the new chunk to each server to process.
  for (Server server: servers) {
    server.processChunk(chunk, fft);
  }
}
