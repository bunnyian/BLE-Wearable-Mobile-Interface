class StreamRecording {
  List<double> data = [];
  List<int> timestamps = []; //seconds from start of recording

  StreamRecording();

  addData(int newTimestamp, double newData) {
    data.add(newData);
    timestamps.add(newTimestamp);
  }

  reset() {
    data = [];
    timestamps = [];
  }
}
