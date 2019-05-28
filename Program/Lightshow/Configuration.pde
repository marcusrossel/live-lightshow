// This file defines the Configuration class which is used in servers to interface with their configuration files.


public final class Configuration {

  private Map<String, Object> staticTraits;
  // This map is updated with new information from the configuration files whenever the time of the last refresh is over a certain threshold.
  private Map<String, Object> runtimeTraits;

  private Path runtimeConfiguration;

  // These properties are used to track whether the maps above need to be refreshed.
  private Integer timeOfLastRefresh;
  private Integer millisecondsToRefresh; // aka refresh interval

  public Configuration(Path staticConfiguration, Path runtimeConfiguration) {
    this.runtimeConfiguration = runtimeConfiguration;
    timeOfLastRefresh = 0;
    millisecondsToRefresh = 0;

    // Creates the static trait map, which has to succeed or else the program has to abort.
    try { staticTraits = mapFromConfiguration(staticConfiguration); } catch (Exception e) {
      println("Internal error: class `Configuration` was unable to create static trait map");
      System.exit(3);
    }

    // Initializes the runtime trait map. This is allowed to fail, as `valueForTrait` will just use the static trait map in that case.
    updateRuntimeTraitConfiguration();
  }

  // Returns the value for the trait with a given name.
  public Object valueForTrait(String trait) {
    // Refreshes the runtime trait map if the refresh interval has been passed.
    if ((millis() - timeOfLastRefresh) > millisecondsToRefresh) {
      updateRuntimeTraitConfiguration();
    }

    // Uses the runtime trait map value if possible - or else falls back on the static trait map.
    // The static value might also be null, if the given trait name string was invalid.
    Object runtimeValue = runtimeTraits.get(trait);
    return (runtimeValue != null) ? runtimeValue : staticTraits.get(trait);
  }

  // Wraps `mapFromConfiguration` to be runtime configuration file specific.
  // It also swallows exceptions and makes sure the `timeOfLastRefresh` is set.
  private void updateRuntimeTraitConfiguration() {
    try { runtimeTraits = mapFromConfiguration(runtimeConfiguration); } catch (Exception e) { /* This is ok. */ }
    timeOfLastRefresh = millis();
  }

  // Creates a map from a given file which is expected to be a sever configuration file of the form:
  // <trait 1 name>:<trait 1 value>:<trait 1 value type>
  // <trait 2 name>:<trait 2 value>:<trait 2 value type>
  // ...
  private Map<String, Object> mapFromConfiguration(Path path) throws Exception {
    Map<String, Object> map = new HashMap<String, Object>();
    Scanner configurationScanner = new Scanner(path);

    // Iterates over the lines in the given file.
    while (configurationScanner.hasNextLine()) {
      String configurationEntry = configurationScanner.nextLine();
      String[] entryComponents = configurationEntry.split(":");

      String traitIdentifier = entryComponents[0];
      // Converts the value from a literal string to the specified type.
      Object value = valueFromStringWithType(entryComponents[1], entryComponents[2]);

      // "Configuration Read Cycle" is a reserved trait name which is used to change the refresh interval of a configuration object.
      if (traitIdentifier == "Configuration Read Cycle") {
        millisecondsToRefresh = Math.round((Float) value);
      } else {
        map.put(traitIdentifier, value);
      }
    }

    configurationScanner.close();
    return map;
  }

  // Converts a given string to a value of given type. If this fails, null is returned.
  private Object valueFromStringWithType(String string, String type) {
     switch (type) {
       case "int":   return Integer.parseInt(string.trim());
       case "float": return Float.parseFloat(string.trim());
       case "bool":  return Boolean.parseBoolean(string.trim());

       case "int-list":
         List<Integer> intList = new ArrayList<Integer>();

         if (string.charAt(0) == 'i') { return intList; }

         String bareIntList = string.substring(1, string.length() - 1);
         String[] intElements = bareIntList.split(",");
         for (String element: intElements) { intList.add(Integer.parseInt(element.trim())); }
         return intList;

       case "float-list":
         List<Float> floatList = new ArrayList<Float>();

         if (string.charAt(0) == 'f') { return floatList; }

         String bareFloatList = string.substring(1, string.length() - 1);
         String[] floatElements = bareFloatList.split(",");
         for (String element: floatElements) { floatList.add(Float.parseFloat(element.trim())); }
         return floatList;

       case "bool-list":
         List<Boolean> boolList = new ArrayList<Boolean>();

         if (string.charAt(0) == 'b') { return boolList; }

         String bareBoolList = string.substring(1, string.length() - 1);
         String[] boolElements = bareBoolList.split(",");
         for (String element: boolElements) { boolList.add(Boolean.parseBoolean(element.trim())); }
         return boolList;

       default:
         return null;
     }
  }
}
