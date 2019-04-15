import java.util.*;
import java.util.stream.Collectors;
import java.util.Random;
import processing.serial.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import cc.arduino.*;


//-------------------------------------------------------------------//
// CLASSES
//-------------------------------------------------------------------//


// TODO: Give each descriptor band Trägheit  

class LoudnessHistory {

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


class BandDescriptor {  

  BandDescriptor(Float lowerBound, Float upperBound, ArrayList<Integer> outputPins, Float loudnessRecalibrationDuration) {
    this.lowerBound = lowerBound;
    this.upperBound = upperBound;
    this.outputPins = outputPins;
    this.loudnessRecalibrationDuration = loudnessRecalibrationDuration;
  }

  ArrayList<Integer> outputPins = new ArrayList<Integer>();

  Float lowerBound = 0f;
  Float upperBound = 0f;

  Float loudnessOfLastFrame = 0f;
  Boolean lastFrameDidTrigger = false; 

  Float maxLoudness = 0f;
  Float recentMaxLoudness = 0f;
  Float loudnessRecalibrationDuration = 0f; // for recentMaxLoudness; in seconds
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
    Integer lowestBand = Math.round(lowerBound / frameSpectrum.getBandWidth());
    Integer highestBand = Math.round(upperBound / frameSpectrum.getBandWidth());

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

  void processCurrentFrame(FFT frameSpectrum) {
    // Gets the loudness of the band in the given frame spectrum.
    loudnessOfLastFrame = bandLoudnessForFrame(frameSpectrum);

    // Resets the `recentMaxLoudness` if the `loudnessRecalibrationDuration` has been exceeded.
    // Else, sets the `recentMaxLoudness` if appropriate.
    if (millis() - timeOfLastTrigger > loudnessRecalibrationDuration * 1000) {
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
    for (Integer pin : outputPins) { 
      arduino.digitalWrite(pin, lastFrameDidTrigger ? Arduino.HIGH : Arduino.LOW);
    }  

    // Records the loudness of this frame.
    loudnessHistory.push(loudnessOfLastFrame);
  }
}

class Visualizer {

  Visualizer(ArrayList<BandDescriptor> bandDescriptors) {
    class BandDescriptorComparator implements Comparator<BandDescriptor> { 
      @Override
        public int compare(BandDescriptor lhs, BandDescriptor rhs) {
        return lhs.lowerBound.compareTo(rhs.lowerBound);
      }
    }

    this.bandDescriptors = bandDescriptors;
    Collections.sort(this.bandDescriptors, new BandDescriptorComparator());

    // Gets a set of all bounds.
    HashSet<Float> allBounds = new HashSet<Float>();
    for (BandDescriptor descriptor : bandDescriptors) {
      allBounds.add(descriptor.upperBound);
      allBounds.add(descriptor.lowerBound);
    }

    // Records the min and max bounds.
    maxBound = Collections.max(allBounds);
    minBound = Collections.min(allBounds);

    initColors();
  }

  private void initColors() {
    colors = new ArrayList<Integer[]>();
    Random random = new Random();

    for (int descriptor = 0; descriptor < bandDescriptors.size(); descriptor++) {
      Integer[] descriptorColor = {0, 0, 0};

      for (int component = 0; component < 3; component++) {
        descriptorColor[component] = random.nextInt(255) + 100;
      }

      colors.add(descriptorColor);
    }
  }

  ArrayList<BandDescriptor> bandDescriptors;

  // Records the biggest and smallest bounds of the band descriptors.
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
    Integer responsibleDescriptorIndex = 0;
    BandDescriptor responsibleDescriptor = bandDescriptors.get(responsibleDescriptorIndex);
    Integer[] bandColor = colors.get(responsibleDescriptorIndex);
    for (Integer band = minBand; band <= maxBand; band++) {
      Float frequency = band * frameBandWidth;

      // Adjusts the `resposibleDescriptor` when necessary.
      if (frequency > responsibleDescriptor.upperBound) {
        // Repeat this band with a different responsible descriptor and color.
        responsibleDescriptorIndex++;
        if (responsibleDescriptorIndex == bandDescriptors.size()) { break; }
        responsibleDescriptor = bandDescriptors.get(responsibleDescriptorIndex);

        band--;
        bandColor = colors.get(responsibleDescriptorIndex);

        continue;
      } else if (frequency < responsibleDescriptor.lowerBound) {
        band = (int) Math.floor(responsibleDescriptor.lowerBound / frameBandWidth);
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

  // Draws the band descriptors' loudness of last frame, rectent max loudness, trigger threshold, and minimal trigger loudness.
  void visualizeDescriptorParameters() {
    for (Integer descriptorIndex = 0; descriptorIndex < bandDescriptors.size(); descriptorIndex++) {
      BandDescriptor descriptor = bandDescriptors.get(descriptorIndex);

      Integer boundOffsetBeginning = Math.round(map(descriptor.lowerBound, minBound, maxBound, 0, width));
      Integer boundOffsetEnd = Math.round(map(descriptor.upperBound, minBound, maxBound, 0, width));
      Integer segementLength = boundOffsetEnd - boundOffsetBeginning;

      Integer lastLoudnessOffset = Math.round(map(descriptor.loudnessOfLastFrame, 0, descriptor.maxLoudness, height, 0));
      Integer rmlOffset = Math.round(map(descriptor.recentMaxLoudness, 0, descriptor.maxLoudness, height, 0));
      Integer triggerThresholdOffset = Math.round(map(descriptor.triggerTreshold * descriptor.recentMaxLoudness, 0, descriptor.maxLoudness, height, 0));
      Integer mttOffset = Math.round(map(descriptor.minimalTriggerThreshold, 0, 1, height, 0));

      strokeWeight(3);
      stroke(255, 255, 255);
      if (descriptor.lastFrameDidTrigger) {
        Integer[] descriptorColor = colors.get(descriptorIndex);
        fill(descriptorColor[0], descriptorColor[1], descriptorColor[2], 150);
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


//-------------------------------------------------------------------//
// GLOBAL OBJECTS
//-------------------------------------------------------------------//


Arduino arduino;
Minim minim;
// AudioPlayer song;
AudioInput input;
FFT fft;
ArrayList<BandDescriptor> bandDescriptors;
Visualizer visualizer;


//-------------------------------------------------------------------//
// SETUP
//-------------------------------------------------------------------//


void setup() {
  // Sets the window size.
  size(1280, 720, P3D);

  // Initializes the non-native objects.
  minim = new Minim(this);
  input = minim.getLineIn();
  // song = minim.loadFile("test_song5.mp3", 2048);
  fft = new FFT(input.bufferSize(), input.sampleRate());
  String arduinoPath = "";

  if (args != null && args.length == 1) {
    arduinoPath = args[0];
  } else {
    System.err.println("Error: Expected <arduino device path> as parameter");
    exit();
  }

  arduino = new Arduino(this, arduinoPath, 57600);

  // Initializes the band descriptors.
  bandDescriptors = new ArrayList<BandDescriptor>(Arrays.asList(
    new BandDescriptor(30f, 300f, new ArrayList<Integer>(Arrays.asList(2, 3, 4)), 2f), 
    new BandDescriptor(300f, 4000f, new ArrayList<Integer>(Arrays.asList(5, 6, 7)), 4f), 
    new BandDescriptor(4000f, 16000f, new ArrayList<Integer>(Arrays.asList(8, 9, 10)), 5f)
   ));

  // Initializes the visualizer.
  visualizer = new Visualizer(bandDescriptors);

  // Initializes the Arduino's pins.
  for (BandDescriptor bandDescriptor : bandDescriptors) {
    for (Integer pin : bandDescriptor.outputPins) {
      arduino.pinMode(pin, Arduino.OUTPUT);
    }
  }

  // Starts playing the song. 
  // song.play();
}


//-------------------------------------------------------------------//
// TEARDOWN
//-------------------------------------------------------------------//


void stop() {
  input.close();
  minim.stop();
  super.stop();
}


//-------------------------------------------------------------------//
// MAIN
//-------------------------------------------------------------------//

void draw() {
  background(0);

  fft.forward(input.mix);
  for (BandDescriptor descriptor : bandDescriptors) { 
    descriptor.processCurrentFrame(fft);
  }
  visualizer.visualizeWaveformForFrame(input.mix);
  visualizer.visualizeDescriptorParameters();
  visualizer.visualizeSpectrumForFrame(fft, true);
}
