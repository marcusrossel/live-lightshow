// # TODO: Give Default Servers inertia.


// ---------------- //
// Loudness History //
// ---------------- //

// TODO: Clean this up.
final class LoudnessHistory {

  LoudnessHistory(Float duration) {
    this.duration = duration;
  }

  private List<Float> loudnesses = new ArrayList<Float>();
  private List<Integer> timeStamps = new ArrayList<Integer>();
  private Float duration;

  private List<Float> relevantHistory() {
    Integer now = millis();

    // Gets the index of the oldest time stamp not older than `duration`.
    Integer index = 0;
    for (; now - timeStamps.get(index) > duration * 1000; index++);

    return loudnesses.subList(index, loudnesses.size() - 1);
  }

  void push(Float loudness) {
    loudnesses.add(loudness);
    timeStamps.add(millis());

    // Consider resizing when reaching more than 500 samples.
    if (loudnesses.size() > 500) {
      Integer oldestTimeStamp = timeStamps.get(0);
      Integer newestTimeStamp = timeStamps.get(timeStamps.size() - 1);

      // Resize when at least 2 * duration of time is recorded.
      if (newestTimeStamp - oldestTimeStamp > (2 * duration * 1000)) {
        loudnesses = relevantHistory();
        timeStamps = timeStamps.subList(timeStamps.size() - loudnesses.size(), timeStamps.size() - 1);
      }
    }
  }

  Float average() {
    if (loudnesses.isEmpty()) {
      return 0f;
    }

    Float sum = 0f;
    List<Float> currentHistory = relevantHistory();
    for (Float value : currentHistory) {
      sum += value;
    }
    return sum / currentHistory.size();
  }
}


// -------------- //
// Default Server //
// -------------- //

// # TODO: Clean this up.

// #server "default"
final class DefaultServer implements Server {

  private Configuration configuration;

  public DefaultServer(Configuration configuration) {
    this.configuration = configuration;
  }

  // #trait "Lower Frequency Bound": 0
  private Float lowerBound() { return configuration.valueForTrait("Lower Frequency Bound"); }

  // #trait "Upper Frequency Bound": 0
  private Float upperBound() { return configuration.valueForTrait("Upper Frequency Bound"); }

  // #trait "Loudness Recalibration Duration": 0
  private Float loudnessRecalibrationDuration() { return configuration.valueForTrait("Loudness Recalibration Duration"); }

  // # TODO: Figure out how to deal with non-Float traits.
  // #trait "Output Pins": [Integer]
  private List<Integer> outputPins() { return new ArrayList<Integer>(); }

  Float loudnessOfLastFrame = 0f;
  Boolean lastFrameDidTrigger = false;

  Float maxLoudness = 0f;
  Float recentMaxLoudness = 0f;
  Float minimalTriggerThreshold = 0.3; // relative to maxLoudness
  Float triggerTreshold = 0.7; // relative to recentMaxLoudness
  Integer timeOfLastTrigger = 0; // relative to program-start; in milliseconds
  LoudnessHistory loudnessHistory = new LoudnessHistory(1f);

  // https://github.com/audiojs/a-weighting
  private Float aWeightedFrequency(Float frequency) {
    Float frequency2 = pow(frequency, 2);
    Float dividend = 1.2588966 * 148840000 * pow(frequency2, 2);
    Float root = sqrt(frequency2 + 11599.29) * (frequency2 + 544496.41);
    Float divisor = ((frequency2 + 424.36) * root * (frequency2 + 148840000));
    return dividend / divisor;
  }

  // Gets the buffer's loudness via A-weightning and root-mean-square.
  private Float overallLoudnessForFrame(FFT frameSpectrum) {
    Float aWeightedSquareIntensitySum = 0f;
    for (Integer band = 0; band <= frameSpectrum.specSize(); band++) {
      Float aWeightedFrequency = aWeightedFrequency(frameSpectrum.indexToFreq(band));
      Float weightedIntensity = aWeightedFrequency * frameSpectrum.getBand(band);
      aWeightedSquareIntensitySum += pow(weightedIntensity, 2);
    }

    return sqrt(aWeightedSquareIntensitySum / frameSpectrum.specSize());
  }

  // Gets the buffer's loudness via A-weightning and root-mean-square, in the range of this descriptor's bounds.
  private Float bandLoudnessForFrame(FFT frameSpectrum) {
    Integer lowestBand = Math.round(lowerBound() / frameSpectrum.getBandWidth());
    Integer highestBand = Math.round(upperBound() / frameSpectrum.getBandWidth());

    Float aWeightedSquareIntensitySum = 0f;
    for (Integer band = lowestBand; band <= highestBand; band++) {
      Float aWeightedFrequency = aWeightedFrequency(frameSpectrum.indexToFreq(band));
      Float weightedIntensity = aWeightedFrequency * frameSpectrum.getBand(band);
      aWeightedSquareIntensitySum += pow(weightedIntensity, 2);
    }

    Integer bandCount = highestBand - lowestBand;
    Float aWeightedRootMeanSquare = sqrt(aWeightedSquareIntensitySum / bandCount);

    return aWeightedRootMeanSquare;
  }

  void processFrame(AudioBuffer buffer, FFT fft) {
    // Gets the loudness of the band in the given frame spectrum.
    loudnessOfLastFrame = bandLoudnessForFrame(fft);

    // Resets the `recentMaxLoudness` if the `loudnessRecalibrationDuration` has been exceeded.
    // Else, sets the `recentMaxLoudness` if appropriate.
    if (millis() - timeOfLastTrigger > loudnessRecalibrationDuration() * 1000) {
      recentMaxLoudness = loudnessOfLastFrame;
    } else {
      // TODO: This should also be affected by the overall loudness, so not all bands will always be relevant for a given song-segment
      recentMaxLoudness = max(recentMaxLoudness, loudnessOfLastFrame);
    }

    // Causes a flickering of triggers on sustained notes.
    if (loudnessHistory.average() > triggerTreshold * recentMaxLoudness) {
      triggerTreshold = 0.75;
    } else {
      triggerTreshold = 0.7;
    }

    // Sets the overall max loudness if appropriate.
    maxLoudness = max(maxLoudness, loudnessOfLastFrame);

    // Determines whether the current frame requires triggering.
    Float triggerLoudness = max(minimalTriggerThreshold * maxLoudness, triggerTreshold * recentMaxLoudness);
    lastFrameDidTrigger = (loudnessOfLastFrame > triggerLoudness);

    // Resets the `timeOfLastTrigger` if appropriate.
    if (lastFrameDidTrigger) {
      timeOfLastTrigger = millis();
    }

    // Updates the pins' states.
    for (Integer pin : outputPins()) {
      arduino.digitalWrite(pin, lastFrameDidTrigger ? Arduino.HIGH : Arduino.LOW);
    }

    // Records the loudness of this frame.
    loudnessHistory.push(loudnessOfLastFrame);
  }
}
