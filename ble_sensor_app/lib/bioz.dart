class BioZReading {
  final int freq;
  final double real;
  final double imag;

  BioZReading({
    required this.freq,
    required this.real,
    required this.imag,
  });
}

class BioZSpectrum {
  final List<BioZReading> readings;

  BioZSpectrum({
    required this.readings,
  });
}

class BioZRecording {
  List<BioZSpectrum> spectra = [];
  List<int> timestamps = [];

  BioZRecording();

  void addData(int newTimestamp, BioZSpectrum newSpectrum) {
    spectra.add(newSpectrum);
    timestamps.add(newTimestamp);
  }

  void reset() {
    spectra = [];
    timestamps = [];
  }
}
