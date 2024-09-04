import 'dart:async';
import 'dart:convert';
import "dart:typed_data";

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'globals.dart' as globals;
import 'database_services.dart';

import 'stream_recording.dart'; //data of the stream
import 'stream_recording_info.dart'; //metadata of  the stream
import 'bioz.dart';

//class notes
//! this is a DATA only class
/* 
- performs the business logic and DATA collection with respect to a single (data) stream
- the stream is defined by the streamRecordingInfo object
  => this object contains the metadata of the stream
  => eg. subject id, recording id, stream id, device name, service name, characteristic name, stream name, stream units
  => CANNOT be changed dynamically as necessary (final) to avoid bugs
  => delete and create a new stream object when changing data
*/

//?rendering/UI
/*
- widget UI construction and state will be managed by the multistream widget
- multistream widget will manage a list of SingleStream data classes
- stream UI widgets will render dynamically based on the incoming data
!- core goal is to seperate the DATA from the UI
*/

class SingleStream {
  //key state variables
  late StreamRecordingInfo streamRecordingInfo;
  StreamRecording streamRecording = StreamRecording();
  BioZRecording bioZRecording = BioZRecording();

  late final StreamSubscription<BluetoothConnectionState>
      connectionSubscription;

  late StreamSubscription<List<int>> streamSubscription;
  bool isRecording = false;
  bool endRecording = false;

  DatabaseServices db = globals.db;

  int startTime = -1;
  Endian endian = Endian.little;

  int startedDisconnectMs = 0;

  //! special state var for bioz rendering choices
  List<Widget> graphOptions = <Widget>[Text("Fluid"), Text("Cole")];
  List<bool> graphOptionsSelected = [true, false];

  //constructor
  SingleStream(this.streamRecordingInfo) {
    streamSubscription =
        streamRecordingInfo.characteristic!.lastValueStream.listen((data) {
      //on data received behaviour
      onCharacteristicNotification(data);
    });

    //set listen status
    streamRecordingInfo.characteristic!.setNotifyValue(true);

    //*autoreconnect features

    BluetoothDevice device = streamRecordingInfo.characteristic!.device;
    connectionSubscription = device.connectionState.listen((event) async {
      if (event == BluetoothConnectionState.disconnected) {
        print("Stream detected disconnect");
        startedDisconnectMs = DateTime.now().millisecondsSinceEpoch;
      } else if (event == BluetoothConnectionState.connected) {
        print("Stream detected connect");

        print("attempting to reconnect data stream to characteristic");

        if (startedDisconnectMs != 0) {
          int totalDisconnectedMs =
              DateTime.now().millisecondsSinceEpoch - startedDisconnectMs;
          if (globals.subjectSelected == true && isRecording) {
            db.increaseDisconnectTime(streamRecordingInfo, totalDisconnectedMs);
            streamRecordingInfo.disconnectTime += totalDisconnectedMs;
          }

          print("disconnected for: $totalDisconnectedMs ms");

          //reset disconnect timer
          startedDisconnectMs = 0;
        }

        await device.discoverServices();

        try {
          streamSubscription.cancel();
        } catch (e) {
          print("error reconnecting to characteristic: $e");
        }

        streamSubscription =
            streamRecordingInfo.characteristic!.lastValueStream.listen((data) {
          onCharacteristicNotification(data);
        });

        streamRecordingInfo.characteristic!.setNotifyValue(true);
      }
    });
  }

  void onCharacteristicNotification(List<int> data) {
    if (endRecording != true & data.isNotEmpty) {
      final bytes = Uint8List.fromList(data);
      ByteData byteData = ByteData.sublistView(bytes);

      int timestamp = parseTimestamp(byteData, endian);
      if (startTime == -1) {
        startTime = timestamp;
      }
      timestamp = timestamp - startTime;

      //non BioZ streams (regular data)
      if (streamRecordingInfo.isBioZ == false) {
        int spacing = parseSpacing(byteData, endian);
        List<double> dataPoints = parseData(byteData, endian);

        List<int> adjustedTimestamps = [];
        for (int i = 0; i < dataPoints.length; i++) {
          adjustedTimestamps.add(timestamp + (i * spacing));
        }

        for (int i = 0; i < dataPoints.length; i++) {
          streamRecording.addData(adjustedTimestamps[i], dataPoints[i]);
        }

        print(
            "data received, timestamp: $timestamp, spacing: $spacing, number of data points: ${dataPoints.length}");

        if (isRecording) {
          for (int i = 0; i < dataPoints.length; i++) {
            db.insertStreamRecordingData(
                streamRecordingInfo.recordingId,
                streamRecordingInfo.streamId,
                adjustedTimestamps[i],
                dataPoints[i]);
          }
        }
      }
      //BioZ Streams
      else {
        int READING_SIZE_BYTES = 10;
        int numReadings = (byteData.lengthInBytes - 4) ~/ READING_SIZE_BYTES;

        List<BioZReading> readings = [];

        for (int i = 0; i < numReadings; i++) {
          int freq = byteData.getInt16(4 + (i * READING_SIZE_BYTES), endian);
          double real =
              byteData.getFloat32(6 + (i * READING_SIZE_BYTES), endian);
          double imag =
              byteData.getFloat32(10 + (i * READING_SIZE_BYTES), endian);

          BioZReading reading = BioZReading(freq: freq, real: real, imag: imag);
          readings.add(reading);
        }

        BioZSpectrum spectrum = BioZSpectrum(readings: readings);

        bioZRecording.addData(timestamp, spectrum);

        if (isRecording) {
          db.insertBioZRecordingData(streamRecordingInfo.recordingId,
              streamRecordingInfo.streamId, timestamp, spectrum, numReadings);
        }
      }
    }
  }

  String convertDataToString(List<int> data) {
    String dataString = utf8.decode(data, allowMalformed: true);
    return dataString;
  }

  int parseTimestamp(ByteData data, Endian endian) {
    int timestamp = data.getInt32(0, endian);
    return timestamp;
  }

  int parseSpacing(ByteData data, Endian endian) {
    int spacing = data.getInt32(4, endian);
    return spacing;
  }

  List<double> parseData(ByteData data, Endian endian) {
    List<double> parsedData = [];
    int dataLength = data.lengthInBytes;

    for (int i = 8; i < dataLength; i += 4) {
      double dataPoint = data.getFloat32(i, endian);
      parsedData.add(dataPoint);
    }

    return parsedData;
  }

  void startRecording() {
    streamRecordingInfo.characteristic!.setNotifyValue(true);
    //set up db
    db.insertStreamRecordingInfo(streamRecordingInfo);
    if (streamRecordingInfo.isBioZ == false) {
      db.createStreamRecording(
          streamRecordingInfo.recordingId, streamRecordingInfo.streamId);

      //reset datapoints and time
      streamRecording.reset();
    } else {
      db.createBioZRecording(
          streamRecordingInfo.recordingId, streamRecordingInfo.streamId);

      //reset datapoints and time
      bioZRecording.reset();
    }

    startTime = -1;

    //start recording
    isRecording = true;
    print(
        "i am recording, stream id: ${streamRecordingInfo.streamId}, nick name: ${streamRecordingInfo.streamName}");
  }

  //stop (END) recording
  void stopRecording() {
    isRecording = false;
    endRecording = true;
    streamRecordingInfo.characteristic!.setNotifyValue(false);
  }

  void dispose() {
    streamSubscription.cancel();
    connectionSubscription.cancel();
  }
}
