import java.nio.file.Path;

// ------------- //
// Configuration //
// ------------- //

// # TODO: Add documentation.
public final class Configuration {
  
  // # TODO: Make private.
  private Map<String, Object> staticTraits;
  private Map<String, Object> runtimeTraits;
  public Path runtimeConfiguration;
  private Integer timeOfLastRefresh;
  private Integer millisecondsToRefresh; 
  
  public Configuration(Path staticConfiguration, Path runtimeConfiguration) {
    this.runtimeConfiguration = runtimeConfiguration;
    timeOfLastRefresh = 0;
    
    // # TODO: Factor this out, e.g. by automatically adding a trait to the static-traits in the static_index.sh
    millisecondsToRefresh = 5000; 
    
    try { staticTraits = mapFromConfiguration(staticConfiguration); } catch (Exception e) { /* # TODO: Fatal error. */ }  
    updateRuntimeTraitConfiguration();
  }
  
  public Object valueForTrait(String trait) {
    if ((millis() - timeOfLastRefresh) > millisecondsToRefresh) {
      updateRuntimeTraitConfiguration();   
    }
    
    Object runtimeValue = runtimeTraits.get(trait);
    if (runtimeValue != null) {
      return runtimeValue; 
    } else {
      Object staticValue = staticTraits.get(trait);
      if (staticValue != null) { return staticValue; }
      else                     { return null; /* # TODO: Fatal error. */ }
    }
  }
  
  void updateRuntimeTraitConfiguration() {
    timeOfLastRefresh = millis();
    try { runtimeTraits = mapFromConfiguration(runtimeConfiguration); } catch (Exception e) { }
  }
  
  private Map<String, Object> mapFromConfiguration(Path path) throws Exception {
    Map<String, Object> map = new HashMap<String, Object>();
    Scanner configurationScanner = new Scanner(path);
    
    while (configurationScanner.hasNextLine()) {
      String configurationEntry = configurationScanner.nextLine();
      String[] entryComponents = configurationEntry.split(":");
      
      String traitIdentifier = entryComponents[0];
      Object value = valueFromStringWithType(entryComponents[1], entryComponents[2]);
      
      map.put(traitIdentifier, value);
    }
    
    configurationScanner.close();
    return map;
  }
  
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
         // # TODO: Fatal error.
         println("Invalid type.");
         return null;
     }
  }
}
