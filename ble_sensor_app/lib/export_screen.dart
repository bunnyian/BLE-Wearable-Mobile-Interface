import 'dart:core';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:toastification/toastification.dart';

import 'database_services.dart';

import 'recording.dart';
import 'stream_recording_info.dart';
import 'stream_recording.dart';
import 'subject.dart';

import 'globals.dart' as globals;

//pull list of all recordings from db
//display list of recordings as check tiles
//when >=1 recording is selected, display export button (floating action)

//app bar with filter buttons
//filter by recording id (default: descending), tap again ascending
//filter by subject id (default: descending), tap again descending
//one filter at a time (reset the other onTap of one)
//todo hidden button to delete and reset db
//todo fix the sorting button icons and pictures for recordings and subject

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DatabaseServices db = globals.db;

  bool isRecordingSelected = false;
  bool noRecordings = false;

  bool recordingIdAscending = true;
  bool recordingIdDescending = false;

  bool subjectIdAscending = false;
  bool subjectIdDescending = false;

  late Future<List<Recording>> recordings = db.recordings();
  List<Recording> selectedRecordings = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarGenerator(context),
      body: FutureBuilder(
        future: recordings,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            sortRecordings(snapshot.data!);
            return ListView.builder(
              itemBuilder: (context, index) {
                return CheckboxListTile(
                  value: selectedRecordings.contains(snapshot.data?[index]),
                  title: Text(
                      "RecID: ${snapshot.data?[index].recordingId}, SubID: ${snapshot.data?[index].subjectId}, Date: ${snapshot.data?[index].startTime.substring(0, 10)}"),
                  subtitle:
                      Text("${snapshot.data?[index].numberOfStreams} streams"),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? value) {
                    if (value == true) {
                      setState(() {
                        selectedRecordings.add(snapshot.data![index]);
                      });
                    } else {
                      setState(() {
                        selectedRecordings.remove(snapshot.data![index]);
                        if (selectedRecordings.isEmpty) {}
                      });
                    }

                    printSelected();
                  },
                );
              },
              itemCount: snapshot.data?.length,
            );
          }
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
      floatingActionButton: ElevatedButton.icon(
          onPressed: () {
            if (selectedRecordings.isNotEmpty) {
              exportThenClear();
            } else {
              toastification.show(
                  description: Text('No recordings selected to export'),
                  type: ToastificationType.error,
                  autoCloseDuration: const Duration(seconds: 3),
                  alignment: Alignment.center);
            }
          },
          icon: Icon(Icons.upload_file, color: Colors.black),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          label: Text(
            "Export",
            style: TextStyle(color: Colors.black),
          )),
    );
  }

  AppBar AppBarGenerator(BuildContext context) {
    return AppBar(
      title: Text('Export Recordings',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 15)),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      actions: [
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            // db.resetAll();
            print("stopped attempt to reset db");
          },
        ),
        IconButton(
          icon: Icon(Icons.fiber_manual_record_outlined),
          onPressed: () {
            if (recordingIdAscending) {
              setState(() {
                recordingIdAscending = false;
                recordingIdDescending = true;

                subjectIdAscending = false;
                subjectIdDescending = false;
              });
            } else {
              setState(() {
                recordingIdAscending = true;
                recordingIdDescending = false;

                subjectIdAscending = false;
                subjectIdDescending = false;
              });
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.person),
          onPressed: () {
            if (subjectIdAscending) {
              setState(() {
                subjectIdAscending = false;
                subjectIdDescending = true;

                recordingIdAscending = false;
                recordingIdDescending = false;
              });
            } else {
              setState(() {
                subjectIdAscending = true;
                subjectIdDescending = false;

                recordingIdAscending = false;
                recordingIdDescending = false;
              });
            }
          },
        )
      ],
    );
  }

  void printSelected() {
    List<int> selectedIds = [];
    for (int i = 0; i < selectedRecordings.length; i++) {
      selectedIds.add(selectedRecordings[i].recordingId);
    }
    print(selectedIds);
  }

  void sortRecordings(List<Recording> recordings) {
    if (recordingIdAscending) {
      recordings.sort((a, b) => a.recordingId.compareTo(b.recordingId));
    } else if (recordingIdDescending) {
      recordings.sort((a, b) => b.recordingId.compareTo(a.recordingId));
    } else if (subjectIdAscending) {
      recordings.sort((a, b) => a.subjectId.compareTo(b.subjectId));
    } else if (subjectIdDescending) {
      recordings.sort((a, b) => b.subjectId.compareTo(a.subjectId));
    }
  }

  void exportThenClear() async {
    await exportRecordings(selectedRecordings);
    setState(() {
      selectedRecordings.clear();
      printSelected();
    });
  }
}

Future<String> exportDirectoryPath() async {
  if (Platform.isAndroid) {
    return '/storage/emulated/0/Download';
  } else {
    Directory? downloads = await getDownloadsDirectory();
    return downloads!.path;
  }
}

Future<void> exportRecordings(List<Recording> recordings) async {
  String path = await exportDirectoryPath();

  //create a directory for this export
  final newDirectory = Directory(
      '$path/Exported_Recordings_${DateTime.now().toString().substring(0, 10)}');
  newDirectory.createSync();

  for (Recording recording in recordings) {
    exportRecording(newDirectory.path, recording);
  }
}

void exportRecording(String path, Recording recording) async {
  DatabaseServices db = globals.db;
  //path is the director for that export

  //create a new directory for the recording
  final newDirectory = Directory(
      '$path/Recording_${recording.recordingId}_Subject_${recording.subjectId}');
  newDirectory.createSync();

  //fetch subject
  Subject subject = await db.getSubject(recording.subjectId);
  String disconnectTimes = '';
  for (int i = 1; i < recording.numberOfStreams + 1; i++) {
    int disconnectedTime = await db.getDisconnectTime(recording.recordingId, i);
    disconnectTimes += 'Stream $i: ${disconnectedTime}\n';
  }

  //first store metadata
  File metadataFile = File('${newDirectory.path}/metadata.txt');
  await metadataFile.writeAsString('Recording ID: ${recording.recordingId}\n'
      'Subject ID: ${recording.subjectId}\n'
      'Start Time: ${recording.startTime}\n'
      'Number of Streams: ${recording.numberOfStreams}\n\n'
      'Disconnect Times, by Stream ID:\n'
      '$disconnectTimes\n\n'
      'Subject Information\n'
      'Sex: ${subject.sex}\n'
      'Birthday: ${subject.birthday}\n'
      'Weight: ${subject.weight}\n'
      'Height: ${subject.height}\n\n'
      'Notes: \n${subject.notes}\n');

  //then store the stream info as seperate csv files
  List<Map> maps = await db.getStreamRecordingInfo(recording.recordingId);

  for (Map map in maps) {
    exportStream(
        newDirectory.path,
        recording.recordingId,
        map['stream_id'],
        map['device_name'],
        map['characteristic_name'],
        map['stream_name'],
        map['stream_units'],
        (map['is_bioz']?.isOdd ?? false));
  }
}

Future<void> exportStream(
    String path,
    int recordingId,
    int streamId,
    String deviceName,
    String characteristicName,
    String streamName,
    String streamUnits,
    bool isBioz) async {
  String filename =
      '${streamId}_${deviceName}_${characteristicName}_${streamName}';
  final dataFile = File('$path/$filename.csv');

  DatabaseServices db = globals.db;

  List<Map> maps = await db.getStreamRecordingData(recordingId, streamId);

  if (isBioz == false) {
    await dataFile.writeAsString("Time (ms),${streamName}(${streamUnits})\n");

    for (Map map in maps) {
      await dataFile.writeAsString("${map['timestamp']}, ${map['data']}\n",
          mode: FileMode.append);
    }
  } else {
    await dataFile
        .writeAsString("Time (ms), Frequency (kHz), Real (Ω), Imaginary (Ω)\n");

    for (Map map in maps) {
      await dataFile.writeAsString(
          "${map['timestamp']}, ${map['freq']}, ${map['real']}, ${map['imag']}\n",
          mode: FileMode.append);
    }
  }
}

//todo export subject roster list functionality (for now keep subject info seperate from recordings)