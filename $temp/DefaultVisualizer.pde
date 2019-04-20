final class DefaultVisualizer {

  DefaultVisualizer(ArrayList<DefaultServer> defaultServers) {
    class DefaultServerComparator implements Comparator<DefaultServer> {
      @Override
        public int compare(DefaultServer lhs, DefaultServer rhs) {
        return lhs.lowerBound().compareTo(rhs.lowerBound());
      }
    }

    this.defaultServers = defaultServers;
    Collections.sort(this.defaultServers, new DefaultServerComparator());

    // Gets a set of all bounds.
    HashSet<Float> allBounds = new HashSet<Float>();
    for (DefaultServer server : defaultServers) {
      allBounds.add(server.upperBound());
      allBounds.add(server.lowerBound());
    }

    // Records the min and max bounds.
    maxBound = Collections.max(allBounds);
    minBound = Collections.min(allBounds);

    initColors();
  }

  private void initColors() {
    colors = new ArrayList<Integer[]>();
    Random random = new Random();

    for (int server = 0; server < defaultServers.size(); server++) {
      Integer[] serverColor = {0, 0, 0};

      for (int component = 0; component < 3; component++) {
        serverColor[component] = random.nextInt(255) + 100;
      }

      colors.add(serverColor);
    }
  }

  ArrayList<DefaultServer> defaultServers;

  // Records the biggest and smallest bounds of the band servers.
  Float maxBound;
  Float minBound;

  // Records the highest and lowest amplitudes the visualizer has ever displayed.
  Float maxAmplitude = 0f;
  Float minAmplitude = 0f;

  // Records the highest intensity of a frequency ever measured.
  Float maxIntensity = 0f;

  // The colors used for visualization.
  ArrayList<Integer[]> colors;

  void visualizeWaveformForFrame(AudioBuffer frame) {
    Integer sampleCount = frame.size();

    strokeWeight(1);
    stroke(255, 255, 255, 20);
    for (Integer sample = 0; sample < sampleCount; sample++) {
      Float amplitude = frame.get(sample);

      maxAmplitude = max(maxAmplitude, amplitude);
      minAmplitude = min(minAmplitude, amplitude);

      float sampleOffset = map(sample, 0, sampleCount - 1, 0, width);
      float amplitudeOffset = map(amplitude, minAmplitude, maxAmplitude, height, 0);

      line(sampleOffset, height / 2, sampleOffset, amplitudeOffset);
    }
  }

  private Float aWeightedFrequency(Float frequency) {
    Float frequency2 = pow(frequency, 2);
    Float dividend = 1.2588966 * 148840000 * pow(frequency2, 2);
    Float root = sqrt(frequency2 + 11599.29) * (frequency2 + 544496.41);
    Float divisor = ((frequency2 + 424.36) * root * (frequency2 + 148840000));
    return dividend / divisor;
  }

  void visualizeSpectrumForFrame(FFT frame, Boolean withAWeighting) {
    Float frameBandWidth = frame.getBandWidth();
    Integer maxBand = Math.round(maxBound / frameBandWidth);
    Integer minBand = Math.round(minBound / frameBandWidth);

    // Draws the band intensities.
    Integer responsibleServerIndex = 0;
    DefaultServer responsibleServer = defaultServers.get(responsibleServerIndex);
    Integer[] bandColor = colors.get(responsibleServerIndex);
    for (Integer band = minBand; band <= maxBand; band++) {
      Float frequency = band * frameBandWidth;

      // Adjusts the `resposibleServer` when necessary.
      if (frequency > responsibleServer.upperBound()) {
        // Repeat this band with a different responsible server and color.
        responsibleServerIndex++;
        if (responsibleServerIndex == defaultServers.size()) { break; }
        responsibleServer = defaultServers.get(responsibleServerIndex);

        band--;
        bandColor = colors.get(responsibleServerIndex);

        continue;
      } else if (frequency < responsibleServer.lowerBound()) {
        band = (int) Math.floor(responsibleServer.lowerBound() / frameBandWidth);
        continue;
      }

      Float intensity = frame.getBand(band) * (withAWeighting ? aWeightedFrequency(frame.indexToFreq(band)) : 1);
      maxIntensity = max(maxIntensity, intensity);

      Integer bandOffset = Math.round(map(frequency, minBound, maxBound, 0, width));
      Integer intensityOffset = Math.round(map(intensity, 0, maxIntensity, height, 0));

      strokeWeight(2);
      stroke(bandColor[0], bandColor[1], bandColor[2]);
      line(bandOffset, height, bandOffset, intensityOffset);
    }
  }

  // Draws the band servers' loudness of last frame, rectent max loudness, trigger threshold, and minimal trigger loudness.
  void visualizeServerParameters() {
    for (Integer serverIndex = 0; serverIndex < defaultServers.size(); serverIndex++) {
      DefaultServer server = defaultServers.get(serverIndex);

      Integer boundOffsetBeginning = Math.round(map(server.lowerBound(), minBound, maxBound, 0, width));
      Integer boundOffsetEnd = Math.round(map(server.upperBound(), minBound, maxBound, 0, width));
      Integer segementLength = boundOffsetEnd - boundOffsetBeginning;

      Integer lastLoudnessOffset = Math.round(map(server.loudnessOfLastFrame, 0, server.maxLoudness, height, 0));
      Integer rmlOffset = Math.round(map(server.recentMaxLoudness, 0, server.maxLoudness, height, 0));
      Integer triggerThresholdOffset = Math.round(map(server.triggerTreshold * server.recentMaxLoudness, 0, server.maxLoudness, height, 0));
      Integer mttOffset = Math.round(map(server.minimalTriggerThreshold, 0, 1, height, 0));

      strokeWeight(3);
      stroke(255, 255, 255);
      if (server.lastFrameDidTrigger) {
        Integer[] serverColor = colors.get(serverIndex);
        fill(serverColor[0], serverColor[1], serverColor[2], 150);
      } else {
        fill(255, 255, 255, 5);
      }
      rect(boundOffsetBeginning, lastLoudnessOffset, segementLength, height - lastLoudnessOffset);

      strokeWeight(5);

      stroke(255, 0, 0);
      line(boundOffsetBeginning, rmlOffset, boundOffsetEnd, rmlOffset);

      stroke(0, 255, 0);
      line(boundOffsetBeginning, triggerThresholdOffset, boundOffsetEnd, triggerThresholdOffset);

      stroke(0, 0, 255, 200);
      line(boundOffsetBeginning, mttOffset, boundOffsetEnd, mttOffset);
    }
  }
}
