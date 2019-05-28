// This file defines the interface to which Live Lightshow server types must conform.


// A type can declare itself a server if it is able to process audio chunks continuously.
// A runtime-checked requirement is also that it is initializable from a Configuration and Arduino object.
interface Server {

  // A buffer can be expected to contain 1024 samples. The fft object will already be forwarded.
  void processChunk(AudioBuffer buffer, FFT fft);

  // Runtime requirement:
  // Server(Configuration configuration, Arduino arduino);
  //
  // This is currently not implementable in Processing, as static method requirements are not possible in non-static nested classes.
}
