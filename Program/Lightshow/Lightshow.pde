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


//-GLOBAL-OBJECTS----------------------------------------------------//


Arduino arduino;
Minim minim;
AudioInput input;
FFT fft;
List<Server> servers;


//-SETUP-------------------------------------------------------------//


void setup() {
  size(1280, 720, P3D);

  minim = new Minim(this);
  input = minim.getLineIn();
  fft = new FFT(input.bufferSize(), input.sampleRate());

  String arduinoPath = "";
  String serverClassList = "";
  String instanceIDServerIDMapPath = "";
  String instanceIDRuntimeConfigFileMapPath = "";
  String serverIDStaticConfigFileMapPath = "";

  if (args != null && args.length == 5) {
    arduinoPath = args[0];
    serverClassList = args[1];
    instanceIDServerIDMapPath = args[2];
    instanceIDRuntimeConfigFileMapPath = args[3];
    serverIDStaticConfigFileMapPath = args[4];
  } else {
    return; // # TODO: Fatal error.
  }

  arduino = new Arduino(this, arduinoPath, 57600);
  for (Integer pin = 2; pin <= 13; pin++) {
    arduino.pinMode(pin, Arduino.OUTPUT);
  }

  List<Configuration> configurations = new ArrayList<>();
  try {
    ConfigurationFactory configurationFactory = new ConfigurationFactory(
      instanceIDServerIDMapPath,
      instanceIDRuntimeConfigFileMapPath,
      serverIDStaticConfigFileMapPath
     );

     Scanner instanceIDServerIDMapScanner = new Scanner(Paths.get(instanceIDServerIDMapPath));
     while (instanceIDServerIDMapScanner.hasNextLine()) {
       String mapEntry = instanceIDServerIDMapScanner.nextLine();
       String[] components = mapEntry.split(": ");
       Optional<Configuration> configuration = configurationFactory.configurationForInstanceID(components[0]);

       if (configuration.isPresent()) {
         configurations.add(configuration.get());
       } else {
         return; // # TODO: Fatal error.
       }
     }
  } catch (Exception _) {
    return; // # TODO: Fatal error.
  }

  Scanner serverClassScanner = new Scanner(serverClassList)
  for (Integer instance = 0; serverClassScanner.hasNextLine(); instance++) {
    String serverClassName = serverClassScanner.nextLine();
    try {
      Class serverClass = Class.forName("serverClassName");
      Constructor serverConstructor = serverClass.getConstructor(Configuration.class);
      Server server = (Server) serverConstructor.newInstance(configurations.get(instance));
      servers.add(server);
    } catch (Exception _) {
      return; // # TODO: Fatal error.
    }
  }
  serverClassScanner.close();
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
