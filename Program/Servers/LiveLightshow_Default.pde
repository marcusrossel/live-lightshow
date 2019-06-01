// This file defines the 'default' server provided with Live Lightshow along with a type used by the server itself.


//-SERVER------------------------------------------------------------//

/*
#info-begin
The 'default' server uses dynamic loudness thresholds to determine when to output HIGH or LOW signals to specified Arduino pins. Passing a HIGH signal is called 'triggering' in the following.

Mechanism:
A maximum loudness (maxL) is recorded over the lifetime of the server. It is simply the loudness of the loudest audio-sample detected. This value is used to determine a minimal loudness which needs to be passed, before even considering triggering. This also entails a flaw with this server, in which turning down the volume of the audio input can cause the server to scarcely trigger, or not trigger at all. This can currently only be fixed by restarting the light show - thereby resetting the maxL of the server. The value is reset to 0 though if either of the frequency bounds are changed.
Another characteristic is the recent average loudness (RAL). This value simply describes the average loudness value out of all of the loudness values of the last x seconds (where x is configurable). It is used to determine when to trigger, by checking whether an audio sample is significantly louder than the RAL. Using a dynamically adjusting average implies that the server can adjust to varying loudness of the audio input.

Traits:
∙ "Output Pins": a list of the pins to which the output signals should be sent. This trait has a default value of 'i[]' and therefore needs to be reconfigured, for the server to show any output. It should be noted that only the digital pins of the Arduino are adressable.
∙ "Lower Frequency Bound": specifies the lower bound of the frequency range which is taken into account during the server's analysis. The value is given in Hz, so sensible values are in the range of 0-20000.
∙ "Lower Frequency Bound": specifies the upper bound of the frequency range which is taken into account during the server's analysis. The value is given in Hz, so sensible values are in the range of 0-20000.
∙ "Minimal Trigger Treshold": specifies the percentage of maxL required for the possibility of triggering. This can e.g. be used to make sure that quiet sections of audio do not cause triggering. Values for this trait should be in the range 0-1.
∙ "History Interval": specifies the duration over which the RAL is formed. The value is given in units of seconds.
∙ "Trigger Threshold": specifies how much louder than the RAL an audio sample has to be, in order for it to cause triggering. This value will usually lie in the range of 1-3. The effect of triggering can be subdued if the loudness of the sample is below the minimum trigger threshold (relative to maxL).
#info-end
*/

// #server "default"
public final class LiveLightshow_Default implements Server {

  private Configuration configuration;
  private Arduino arduino;

  public LiveLightshow_Default(Configuration configuration, Arduino arduino) {
    this.configuration = configuration;
    this.arduino = arduino;
     this.loudnessHistory = new LiveLightshow_LoudnessHistory(historyInterval());
  }

  // #trait "Lower Frequency Bound": 0.0
  private Float lowerBound() { return (Float) configuration.valueForTrait("Lower Frequency Bound"); }

  // #trait "Upper Frequency Bound": 20000.0
  private Float upperBound() { return (Float) configuration.valueForTrait("Upper Frequency Bound"); }

  // #trait "History Interval": 2.0
  private Float historyInterval() { return (Float) configuration.valueForTrait("History Interval"); }

  // #trait "Trigger Threshold": 1.25
  private Float triggerTreshold() { return (Float) configuration.valueForTrait("Trigger Threshold"); } // relative to the recent average loudness

  // #trait "Minimal Trigger Threshold": 0.3
  private Float minimalTriggerThreshold() { return (Float) configuration.valueForTrait("Minimal Trigger Threshold"); } // relative to the total maximum loudness

  // #trait "Output Pins": i[]
  private List<Integer> outputPins() { return (List<Integer>) configuration.valueForTrait("Output Pins"); }

  // The A-weighted loudness of the last processed chunk, in the frequency bounds during that time.
  private Float recordedLoudness = 0f;

  private Boolean didTrigger = false;
  private Boolean didTriggerOnLastChunk = false;

  // The maximum A-weighted loudness of all processed chunk so far, in the frequency bounds during their time. This property is reset when a frequency bound changes.
  private Float totalMaxLoudness = 0f;
  private Float recentAverageLoudness = 0f;

  // A record of the values of the frequency bounds during processing of the last chunk.
  private Float[] previousFrequencyBounds = new Float[]{0f, 0f};

  LiveLightshow_LoudnessHistory loudnessHistory;

  // Resets the total maximum loudness whenever the the frequency bounds have changed.
  private void resetTotalMaxLoundessIfNecessary() {
      Float lowerBound = lowerBound();
      Float upperBound = upperBound();

      if (lowerBound.equals(previousFrequencyBounds[0]) && upperBound.equals(previousFrequencyBounds[1])) { return; }

      totalMaxLoudness = 0f;
      previousFrequencyBounds[0] = lowerBound;
      previousFrequencyBounds[1] = upperBound;
  }

  // https://en.wikipedia.org/wiki/A-weighting
  // https://github.com/audiojs/a-weighting
  private Float aWeightedFrequency(Float frequency) {
    Float frequency2 = pow(frequency, 2);
    Float dividend = 1.2588966 * 148840000 * pow(frequency2, 2);
    Float root = sqrt(frequency2 + 11599.29) * (frequency2 + 544496.41);
    Float divisor = ((frequency2 + 424.36) * root * (frequency2 + 148840000));
    return dividend / divisor;
  }

  // Gets the chunk's loudness via A-weighting and root-mean-square, within the given frequency bounds.
  private Float bandLoudnessForChunk(FFT chunkSpectrum) {
    Integer lowestBand = Math.round(lowerBound() / chunkSpectrum.getBandWidth());
    Integer highestBand = Math.round(upperBound() / chunkSpectrum.getBandWidth());
    Integer bandCount = highestBand - lowestBand;

    if (bandCount < 1) { return 0f; }

    Float aWeightedSquareIntensitySum = 0f;
    for (Integer band = lowestBand; band <= highestBand; band++) {
      Float aWeightedFrequency = aWeightedFrequency(chunkSpectrum.indexToFreq(band));
      Float weightedIntensity = aWeightedFrequency * chunkSpectrum.getBand(band);
      aWeightedSquareIntensitySum += pow(weightedIntensity, 2);
    }

    Float aWeightedRootMeanSquare = sqrt(aWeightedSquareIntensitySum / bandCount);

    return aWeightedRootMeanSquare;
  }

  void processChunk(AudioBuffer buffer, FFT fft) {
    // Passes down whether or not the last chunk did trigger.
    didTriggerOnLastChunk = didTrigger;
    // Updates the loudness history retention duration.
    loudnessHistory.retentionDuration = historyInterval();

    resetTotalMaxLoundessIfNecessary();

    // Gets the loudness of the current chunk within the frequency bounds.
    recordedLoudness = bandLoudnessForChunk(fft);
    // Records the loudness of this chunk.
    loudnessHistory.push(recordedLoudness);
    // Sets the overall max loudness if appropriate.
    totalMaxLoudness = max(totalMaxLoudness, recordedLoudness);
    // Gets the average loudness of the last (history interval) seconds.
    recentAverageLoudness = loudnessHistory.average();

    // Determines the loudness above which triggering occurs. It will never be lower than (minimal trigger threshold * total maximum loudness).
    Float triggerLoudness = max(minimalTriggerThreshold() * totalMaxLoudness, triggerTreshold() * recentAverageLoudness);
    // Determines whether the current chunk triggers.
    didTrigger = (recordedLoudness > triggerLoudness);

    // Updates the output pins' states if necessary.
    if (didTrigger != didTriggerOnLastChunk) {
      Integer newOutput = didTrigger ? Arduino.HIGH : Arduino.LOW;
      for (Integer pin : outputPins()) { arduino.digitalWrite(pin, newOutput); }
    }
  }
}


//-LOUDNESS-HISTORY--------------------------------------------------//


// A LoudnessHistory is a time-bounded FIFO for loudness values.
// Addition of values is done manually via the `push` method. Removal of values though, happens automatically for all values older than a given time interval.
// This way you can keep track of the last n seconds of loudness values.
private final class LiveLightshow_LoudnessHistory {

  LiveLightshow_LoudnessHistory(Float retentionDuration) {
    this.retentionDuration = retentionDuration;
  }

  private List<Float> loudnesses = new ArrayList<Float>();
  private List<Integer> timeStamps = new ArrayList<Integer>();

  // This property is supposed to be setable.
  Float retentionDuration; // in seconds

  // Returns the list of loudness values that are still within the retention duration.
  private List<Float> relevantHistory() {
    Integer now = millis();

    // Gets the index of the oldest time stamp not older than the retention duration. If there is none, an empty array is returned.
    Integer index = 0;
    while (now - timeStamps.get(index) > retentionDuration * 1000) {
      index++;
      if (index == timeStamps.size()) { return new ArrayList<Float>(); }
    }

    return loudnesses.subList(index, loudnesses.size() - 1);
  }

  // Adds a loudness value to the end of the FIFO.
  void push(Float loudness) {
    Integer now = millis();

    loudnesses.add(loudness);
    timeStamps.add(now);

    // Removes the values that are older than the retention duration.
    // Removal only happens once at least 500 values have accumulated. This is done to reduce the runtime cost of reallocating array memory.
    if (loudnesses.size() > 500) {
      // Removes the values only if the oldest recorded value is at least (2 * retention duration) old.
      // The factor 1000 converts the rentation duration from seconds to milliseconds.
      if (now - timeStamps.get(0) > (2 * retentionDuration * 1000)) {
        loudnesses = relevantHistory();
        timeStamps = timeStamps.subList(timeStamps.size() - loudnesses.size(), timeStamps.size() - 1);
      }
    }
  }

  // # TODO: Form the average by weighting newer samples more heavily than older ones - to allow longer retention without too much inertia.

  // Returns the average of the loudness values that are within the rentention duration.
  Float average() {
    if (loudnesses.isEmpty()) { return 0f; }

    Float sum = 0f;
    List<Float> currentHistory = relevantHistory();
    for (Float value: currentHistory) {
      sum += value;
    }
    return sum / currentHistory.size();
  }
}
