import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class StreamRecordingInfo {
  final int subjectId;
  final int recordingId; //unique id for each recording
  final int streamId; //id increasing from 0 for each stream in a recording
  //in a string there is a sensor id
  //characteristic returns 1 string
  // tells u what device to update
  final BluetoothDevice? device;
  final BluetoothService? service;
  final BluetoothCharacteristic? characteristic;
  final String deviceName; //to be store in database
  final String serviceName;
  final String characteristicName;

  final String streamName; //nickname
  final String streamUnits; //units
  final bool isBioZ;
  int disconnectTime = 0; //ms for how much disconnect time

  StreamRecordingInfo({
    required this.recordingId,
    required this.streamId,
    required this.subjectId,
    required this.device,
    required this.service,
    required this.characteristic,
    required this.deviceName,
    required this.serviceName,
    required this.characteristicName,
    required this.streamName,
    required this.streamUnits,
    required this.isBioZ,
  });

  //convert a StreamRecordingInfo into a Map to be stored in the database
  Map<String, dynamic> toMap() {
    return {
      // 'recording_id': recordingId, //! not needed as the name of this table stores recording id
      'stream_id': streamId,
      'device_name': deviceName,
      'service_name': serviceName,
      'characteristic_name': characteristicName,
      'stream_name': streamName,
      'stream_units': streamUnits,
      'disconnect_time': disconnectTime,
      'is_bioz': isBioZ ? 1 : 0,
    };
  }

  //override toString to make it easier to see the StreamRecordingInfo

  @override
  String toString() {
    return 'StreamRecordingInfo{recordingId: $recordingId, streamId: $streamId, deviceName: $deviceName, serviceName: $serviceName, characteristicName: $characteristicName, streamName: $streamName, streamUnits: $streamUnits, disconnectTime: $disconnectTime}';
  }
}
