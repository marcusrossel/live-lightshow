// # TODO: Clean this up.

import java.nio.file.Path;

// ------------- //
// Configuration //
// ------------- //

public final class Configuration {
  
  private Map<String, Object> staticTraits;
  private Map<String, Object> runtimeTraits;
  private Path runtimeConfiguration;
  private Integer timeOfLastRefresh;
  private Integer millisecondsToRefresh; 
  
  public Configuration(Path staticConfiguration, Path runtimeConfiguration) {
    this.runtimeConfiguration = runtimeConfiguration;
    timeOfLastRefresh = 0;
    millisecondsToRefresh = 0;    
    
    try { staticTraits = mapFromConfiguration(staticConfiguration); } catch (Exception e) {
      println("Internal error: class `Configuration` was unable to create static trait map");
      System.exit(3);
    }  
    
    updateRuntimeTraitConfiguration();
  }
  
  public Object valueForTrait(String trait) {
    if ((millis() - timeOfLastRefresh) > millisecondsToRefresh) {
      updateRuntimeTraitConfiguration();   
    }
    
    Object runtimeValue = runtimeTraits.get(trait);
    return (runtimeValue != null) ? runtimeValue : staticTraits.get(trait);
  }
  
  void updateRuntimeTraitConfiguration() {
    try { runtimeTraits = mapFromConfiguration(runtimeConfiguration); } catch (Exception e) { /* This is ok. */ }
    timeOfLastRefresh = millis();
  }
  
  private Map<String, Object> mapFromConfiguration(Path path) throws Exception {
    Map<String, Object> map = new HashMap<String, Object>();
    Scanner configurationScanner = new Scanner(path);
    
    while (configurationScanner.hasNextLine()) {
      String configurationEntry = configurationScanner.nextLine();
      String[] entryComponents = configurationEntry.split(":");
      
      String traitIdentifier = entryComponents[0];
      Object value = valueFromStringWithType(entryComponents[1], entryComponents[2]);
      
      if (traitIdentifier == "Configuration read cycle (in seconds)") {
        millisecondsToRefresh = Math.round((Float) value);
      } else {
        map.put(traitIdentifier, value); 
      }
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
         return null;
     }
  }
}
