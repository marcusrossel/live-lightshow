// This file defines the 'on-beat' server provided with Live Lightshow.


/*
#info-begin
The 'on-beat' server uses ddf minim's (an audio-library's) 'BeatDetect' class to detect kick-drum beats.
When the onset of a beat is detected a given set of Arduino pins is sent a HIGH signal - otherwise a LOW signal is sent.

The server has two configurable traits.
One are the "Output Pins", which are simply a list of the pins to which the output signals should be sent. This trait has a default value of 'i[]' and therefore needs to be reconfigured, for the server to show any output. It should be noted that only the digital pins of the Arduino are adressable.
The second trait is the "Sensitivity". This property determines what the minimum time-gap between detected beats should be. This value can therefore be adjusted to prevent under- or oversensitivity of the beat detector.
#info-end
*/

// #server "on-beat"
public final class LiveLightshow_OnBeat implements Server {

  private Configuration configuration;
  private Arduino arduino;

  public LiveLightshow_OnBeat(Configuration configuration, Arduino arduino) {
    this.configuration = configuration;
    this.arduino = arduino;

    this.beatDetector = new BeatDetect(1024, 44100);
  }

  // #trait "Sensitivity": 100
  private Integer sensitivity() { return (Integer) configuration.valueForTrait("Sensitivity"); }

  // #trait "Output Pins": i[]
  private List<Integer> outputPins() { return (List<Integer>) configuration.valueForTrait("Output Pins"); }

  private Boolean didTrigger = false;
  private Boolean didTriggerOnLastChunk = false;

  private BeatDetect beatDetector;

  void processChunk(AudioBuffer buffer, FFT fft) {
    beatDetector.setSensitivity(sensitivity());

    // Passes down whether or not the last chunk did trigger.
    didTriggerOnLastChunk = didTrigger;

    // Determines whether the current chunk triggers.
    beatDetector.detect(buffer);
    didTrigger = beatDetector.isKick();

    // Updates the output pins' states if necessary.
    if (didTrigger != didTriggerOnLastChunk) {
      Integer newOutput = didTrigger ? Arduino.HIGH : Arduino.LOW;
      for (Integer pin : outputPins()) { arduino.digitalWrite(pin, newOutput); }
    }
  }
}
