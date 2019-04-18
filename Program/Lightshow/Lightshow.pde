// # TODO: Check these imports.
// # TODO: Add documentation.
import java.util.*;
import java.nio.file.Paths;
import java.lang.reflect.Constructor;
import java.util.stream.Collectors;
import java.util.Random;
import processing.serial.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import cc.arduino.*;

Arduino arduino;
Minim minim;
AudioInput input;
FFT fft;
List<Server> servers;

List<Server> serversForInstantiationMap(String serverInstantiationMap) throws Exception {
  List<Server> instantiatees = new ArrayList<Server>();
  
  // Iterates over the server instantiation map entry for each expected server instance.
  Scanner mapScanner = new Scanner(serverInstantiationMap);
  while (mapScanner.hasNextLine()) {
    // Gets the map entry.
    String mapEntry = mapScanner.nextLine(); 
    String[] entryComponents = mapEntry.split(":");
    
    // Gets the map entry components as their respective types.
    Class instanceClass = Class.forName("$Lightshow" + entryComponents[0]);
    Path staticConfiguration = Paths.get(entryComponents[1]);
    Path runtimeConfiguration = Paths.get(entryComponents[2]);
    
    // Creates the instance's configuration and constructor. 
    Configuration configuration = new Configuration(staticConfiguration, runtimeConfiguration);
    Constructor instanceConstructor = instanceClass.getConstructor(Lightshow.class, Configuration.class);
    
    // Instantiates the instance and adds it to the list of servers.
    Server instance = (Server) instanceConstructor.newInstance(this, configuration);
    instantiatees.add(instance);
  }
  
  mapScanner.close();
  return instantiatees;
}


void setup() {
  size(1280, 720, P3D);
  minim = new Minim(this);
  input = minim.getLineIn();
  fft = new FFT(input.bufferSize(), input.sampleRate());

  String arduinoPath = "";
  String serverInstantiationMap = "";

  if (args != null && args.length == 2) {
    arduinoPath = args[0];
    serverInstantiationMap = args[1];
  } else {
    println("Internal error: `Lightshow.pde` didn't receive the correct number of command line arguments");
    System.exit(1);
  }
  
  try {
    servers = serversForInstantiationMap(serverInstantiationMap);
  } catch (Exception e) {
    // # TODO: Fatal error.
    println(e);
    System.exit(2);
  }

  arduino = new Arduino(this, arduinoPath, 57600);
  for (Integer pin = 2; pin <= 13; pin++) {
    arduino.pinMode(pin, Arduino.OUTPUT);
  }
}


//-TEARDOWN----------------------------------------------------------//


void stop() {
  input.close();
  minim.stop();
  super.stop();
}


//-MAIN--------------------------------------------------------------//


void draw() {
  AudioBuffer chunk = input.mix;
  fft.forward(chunk);

  for (Server server: servers) {
    server.processFrame(chunk, fft);
  }
}
