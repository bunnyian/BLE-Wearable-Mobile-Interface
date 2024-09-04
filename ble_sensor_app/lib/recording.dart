//entry in table recordings
class Recording {
  final int recordingId; //unique id for each recording
  //generate on create (like subject id)
  final int subjectId;
  final String startTime;
  final int numberOfStreams;

  //constructor
  Recording({
    required this.recordingId,
    required this.subjectId,
    required this.startTime,
    required this.numberOfStreams,
  });

  //convert a Recording into a Map to be stored in the database
  Map<String, dynamic> toMap() {
    return {
      'recording_id': recordingId,
      'subject_id': subjectId,
      'start_time': startTime,
      'number_of_streams': numberOfStreams,
    };
  }

  //override toString to make it easier to see the Recording
  @override
  String toString() {
    return 'Recording{recordingId: $recordingId, subjectId: $subjectId, startTime: $startTime, numberOfStreams: $numberOfStreams}';
  }
}
