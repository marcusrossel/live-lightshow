import java.nio.file.Path;

// ------------- //
// Configuration //
// ------------- //

// # TODO: Add documentation.
public final class Configuration {
  
  // # TODO: Make private.
  private Map<String, Float> staticTraits;
  private Map<String, Float> runtimeTraits;
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
  
  public Float valueForTrait(String trait) {
    if ((millis() - timeOfLastRefresh) > millisecondsToRefresh) {
      updateRuntimeTraitConfiguration();   
    }
    
    Float runtimeValue = runtimeTraits.get(trait);
    if (runtimeValue != null) {
      return runtimeValue; 
    } else {
      
      Float staticValue = staticTraits.get(trait);
      if (staticValue != null) { return staticValue; }
      else                     { return null; /* # TODO: Fatal error. */ }
    }
  }
  
  void updateRuntimeTraitConfiguration() {
    timeOfLastRefresh = millis();
    try { runtimeTraits = mapFromConfiguration(runtimeConfiguration); } catch (Exception e) { }
  }
  
  private Map<String, Float> mapFromConfiguration(Path path) throws Exception {
    Map<String, Float> map = new HashMap<String, Float>();
    Scanner configurationScanner = new Scanner(path);
    
    while (configurationScanner.hasNextLine()) {
      String configurationEntry = configurationScanner.nextLine();
      String[] entryComponents = configurationEntry.split(":");
      
      String traitIdentifier = entryComponents[0].trim();
      Float value = Float.parseFloat(entryComponents[1]);
      
      map.put(traitIdentifier, value);
    }
    
    configurationScanner.close();
    return map;
  }
}
