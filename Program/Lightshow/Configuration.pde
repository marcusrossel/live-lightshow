import java.io.FileReader;


// --------------------- //
// Configuration Factory //
// --------------------- //

// # TODO: Add documentation.
public final class ConfigurationFactory {
  
  public ConfigurationFactory(
    String instanceIDServerIDMapPath,
    String instanceIDRuntimeConfigFileMapPath,
    String serverIDStaticConfigFileMapPath
  ) throws Exception {
    instanceIDServerIDMap          = mapFromColonSeperatedEntriesAtPath(instanceIDServerIDMapPath         );
    instanceIDRuntimeConfigFileMap = mapFromColonSeperatedEntriesAtPath(instanceIDRuntimeConfigFileMapPath);
    serverIDStaticConfigFileMap    = mapFromColonSeperatedEntriesAtPath(serverIDStaticConfigFileMapPath   );
  }
  
  private Map<String, String> instanceIDServerIDMap;
  private Map<String, String> instanceIDRuntimeConfigFileMap;
  private Map<String, String> serverIDStaticConfigFileMap;
  
  private Map<String, String> mapFromColonSeperatedEntriesAtPath(String path) throws Exception {
    Map<String, String> map = new HashMap<String, String>();
    FileReader fileReader = new FileReader(path);
    BufferedReader reader = new BufferedReader(fileReader);
    
    String mapEntry;
    while ((mapEntry = reader.readLine()) != null) {
      String[] entryComponents = mapEntry.split(": "); 
      map.put(entryComponents[0], entryComponents[1]);
    }
    
    reader.close();
    return map;
  }
  
  private Map<String, Float> mapTraitConfigurationAtPath(String path) throws Exception {
    Map<String, Float> map = new HashMap<String, Float>();
    FileReader fileReader = new FileReader(path);
    BufferedReader reader = new BufferedReader(fileReader);
    
    String mapEntry;
    while ((mapEntry = reader.readLine()) != null) {
      String[] entryComponents = mapEntry.split(": ");
      Float value = Float.parseFloat(entryComponents[1]); 
      map.put(entryComponents[0], value);
    }
    
    reader.close();
    return map;
  }
  
  public Optional<Configuration> configurationForInstanceID(String instanceID) {
    String runtimeTraitConfigurationFilePath = instanceIDRuntimeConfigFileMap.get(instanceID);
    if (runtimeTraitConfigurationFilePath == null) { return Optional.empty(); }
    
    String serverIDForInstanceID = instanceIDServerIDMap.get(instanceID);
    if (serverIDForInstanceID == null) { return Optional.empty(); }
    String configFileForInstanceID = serverIDStaticConfigFileMap.get(serverIDForInstanceID);
    if (configFileForInstanceID == null) { return Optional.empty(); }
    
    try {
      Map<String, Float> staticTraitConfiguration = mapTraitConfigurationAtPath(configFileForInstanceID);
      return Optional.of(new Configuration(staticTraitConfiguration, runtimeTraitConfigurationFilePath));
    } catch (Exception _) {
      return Optional.empty();
    }
  }
}


// ------------- //
// Configuration //
// ------------- //

// # TODO: Add documentation.
public final class Configuration {
  
  private Map<String, Float> staticTraitConfiguration;
  private Map<String, Float> runtimeTraitConfiguration;
  private String runtimeTraitConfigurationFilePath;
  private Integer timeOfLastRefresh;
  private Integer millisecondsToRefresh; 
  
  protected Configuration(Map<String, Float> staticTraitConfiguration, String runtimeTraitConfigurationFilePath) {
    this.staticTraitConfiguration = staticTraitConfiguration;
    this.runtimeTraitConfigurationFilePath = runtimeTraitConfigurationFilePath;
    runtimeTraitConfiguration = new HashMap<String, Float>();
    timeOfLastRefresh = 0;
    millisecondsToRefresh = 3000; // # TODO: Factor this out. 
    
    updateRuntimeTraitConfiguration();
  }
  
  public Float valueForTrait(String trait) {
    if ((millis() - timeOfLastRefresh) > millisecondsToRefresh) {
      updateRuntimeTraitConfiguration();   
    }
    
    Float runtimeValue = runtimeTraitConfiguration.get(trait);
    if (runtimeValue != null) {
       return runtimeValue; 
    } else {
      Float staticValue = staticTraitConfiguration.get(trait);
      if (staticValue != null) {
        return staticValue;
      } else {
        return 0.0; // # TODO: Fatal error.
      }
    }
  }
  
  void updateRuntimeTraitConfiguration() {
    timeOfLastRefresh = millis();
    try { runtimeTraitConfiguration = mapFromColonSeperatedEntriesAtPath(runtimeTraitConfigurationFilePath); } catch (Exception _) { }
  }
  
  private Map<String, Float> mapFromColonSeperatedEntriesAtPath(String path) throws Exception {
    Map<String, Float> map = new HashMap<String, Float>();
    FileReader fileReader = new FileReader(path);
    BufferedReader reader = new BufferedReader(fileReader);
    
    String mapEntry;
    while ((mapEntry = reader.readLine()) != null) {
      String[] entryComponents = mapEntry.split(": ");
      Float value = Float.parseFloat(entryComponents[1]); 
      map.put(entryComponents[0], value);
    }
    
    reader.close();
    return map;
  }
}
