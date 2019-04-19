interface Server {
  Configuration getConfiguration(); // # TODO: For testing only.
  void processFrame(AudioBuffer buffer, FFT fft);
   // Server(Configuration configuration); # TODO: Figure out how to add a constructor or static method requirement.
}
