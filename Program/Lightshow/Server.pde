interface Server {
  void processFrame(AudioBuffer buffer, FFT fft);

  // # TODO: Figure out how to add a constructor or static method requirement.
  // Server(Configuration configuration, Arduino arduino);
}
