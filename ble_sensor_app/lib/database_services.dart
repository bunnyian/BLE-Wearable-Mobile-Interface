import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:toastification/toastification.dart';

//!!!!!!!!!IMPORTANT!!!!!!!!!
import 'subject.dart'; //top level table
import 'recording.dart'; //top level table
import 'bioz.dart'; //top level table

import 'stream_recording_info.dart'; //one table per recording to store info about the streams

// one table per stream to store the data
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//sql table constructors
const String createSubjects =
    'CREATE TABLE subjects(id INTEGER PRIMARY KEY, birthday STRING, sex TEXT, age INTEGER, weight REAL, height REAL, notes TEXT)';
const String createRecordings =
    'CREATE TABLE recordings(recording_id INTEGER PRIMARY KEY, subject_id INTEGER, start_time STRING, number_of_streams INTEGER)';

String constructorCreateRecordingInfo(int recordingId) {
  //table create command
  // sql table name is $recordingId_info
  return 'CREATE TABLE recording_info_$recordingId(stream_id INTEGER PRIMARY KEY, device_name TEXT, service_name TEXT, characteristic_name TEXT, stream_name TEXT, stream_units TEXT, disconnect_time INTEGER, is_bioz INTEGER)';
}

String constructorCreateStreamRecording(int recordingId, int streamId) {
  //table create command
  // sql table name is $recordingId_$streamId
  return 'CREATE TABLE recording_${recordingId}_stream_$streamId(timestamp INTEGER PRIMARY KEY, data REAL)';
}

String constructorCreateBioZRecording(int recordingId, int streamId) {
  //table create command
  // sql table name is $recordingId_$streamId
  return 'CREATE TABLE recording_${recordingId}_stream_$streamId(sample_id INTEGER PRIMARY KEY, timestamp INTEGER, freq INTEGER, real REAL, imag REAL)';
}

class DatabaseServices {
  //delete db
  Future<void> resetAll() async {
    await deleteDatabase(join(await getDatabasesPath(), 'sensor_companion.db'));
  }

  late Future<Database>
      database; //making database global so that every function inside the class can access it.
  Future<void> initDatabase() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Open the database and store the reference.
    database = openDatabase(
      // Set the path to the database.
      join(await getDatabasesPath(), 'sensor_companion.db'),
      // When the database is first created, create a table to store counters;
      onCreate: (db, version) {
        createTables();
      },

      version: 1,
    );
  }

  void printDatabasePath() async {
    print(await getDatabasesPath());
  }

  //!subjects related
  Future<void> insertSubject(String sex, String birthday, double weight,
      double height, String notes) async {
    Database db = await database;

    //get the last inserted id
    List<Map> lastId = await db.rawQuery('SELECT MAX(id) FROM subjects');
    int newId;
    if ((lastId[0]['MAX(id)']) == null) {
      newId = 1;
    } else {
      newId = lastId[0]['MAX(id)'] + 1;
    }

    Subject newSubject = Subject(
      id: newId,
      sex: sex,
      birthday: birthday,
      weight: weight,
      height: height,
      notes: notes,
    );

    try {
      await db.insert(
        'subjects',
        newSubject.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("Subject added: $newSubject");
    } on Exception catch (e) {
      // TODO
      print("Error adding subject: $e");
    }
  }

  Future<Subject> lastAddedSubject() async {
    List<Subject> subjectsList = await subjects();

    //return the last added subject (highest id)
    return subjectsList[subjectsList.length - 1];
  }

  Future<void> updateSubject(Subject subject) async {
    Database db = await database;

    await db.update(
      'subjects',
      subject.toMap(),
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  //retrieve all subjects
  Future<List<Subject>> subjects() async {
    Database db = await database;

    List<Map<String, dynamic>> maps = await db.query('subjects');

    return List.generate(maps.length, (i) {
      return Subject(
        id: maps[i]['id'],
        sex: maps[i]['sex'],
        birthday: maps[i]['birthday'],
        weight: maps[i]['weight'],
        height: maps[i]['height'],
        notes: maps[i]['notes'].toString(),
      );
    });
  }

  Future<Subject> getSubject(int id) async {
    Database db = await database;

    List<Map> result =
        await db.query('subjects', where: 'id = ?', whereArgs: [id]);

    if (result.isNotEmpty) {
      return Subject(
        id: result[0]['id'],
        sex: result[0]['sex'],
        birthday: result[0]['birthday'],
        weight: result[0]['weight'],
        height: result[0]['height'],
        notes: result[0]['notes'].toString(),
      );
    } else {
      return Subject(
        id: -1,
        sex: "N/A",
        birthday: "N/A",
        weight: -1,
        height: -1,
        notes: "ERROR FETCHING SUBJECT DATA",
      );
    }
  }

  Future<void> testAddingJohn() async {
    await insertSubject("M", DateTime.now().toIso8601String(), 150.0, 70.0, "");
    print(await subjects());
  }

  //! recording
  Future<int> getNextRecordingId() async {
    Database db = await database;
    final List<Map<String, dynamic>> lastId =
        await db.rawQuery('SELECT MAX(recording_id) FROM recordings');
    int newId;
    if ((lastId[0]['MAX(recording_id)']) == null) {
      newId = 1;
    } else {
      newId = lastId[0]['MAX(recording_id)'] + 1;
    }
    return newId;
  }

  Future<void> insertRecording(Recording newRecording) async {
    Database db = await database;

    try {
      await db.insert(
        'recordings',
        newRecording.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("Recording added: $newRecording");
    } on Exception catch (e) {
      // TODO
      print("Error adding recording: $e");
    }
  }

  Future<List<Recording>> recordings() async {
    Database db = await database;

    List<Map<String, dynamic>> maps = await db.query('recordings');

    return List.generate(maps.length, (i) {
      return Recording(
        recordingId: maps[i]['recording_id'],
        subjectId: maps[i]['subject_id'],
        startTime: maps[i]['start_time'],
        numberOfStreams: maps[i]['number_of_streams'],
      );
    });
  }

  //! recording info (table for each recording which stores METADATA about each datastream)
  Future<void> createRecordingInfo(int recordingId) async {
    Database db = await database;
    await db.execute(constructorCreateRecordingInfo(recordingId));
  }

  Future<void> insertStreamRecordingInfo(
      StreamRecordingInfo streamRecordingInfo) async {
    Database db = await database;

    try {
      await db.insert(
        'recording_info_${streamRecordingInfo.recordingId}',
        streamRecordingInfo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("StreamRecordingInfo added: $streamRecordingInfo");
    } on Exception catch (e) {
      // TODO
      print("Error adding StreamRecordingInfo: $e");
    }
  }

  Future<int> getDisconnectTime(int recordingId, int streamId) async {
    Database db = await database;

    List<Map<String, dynamic>> result = await db.query(
        'recording_info_${recordingId}',
        where: 'stream_id = ?',
        whereArgs: [streamId]);

    if (result.isNotEmpty) {
      return result[0]['disconnect_time'];
    } else {
      return -1;
    }
  }

  Future<void> increaseDisconnectTime(
      StreamRecordingInfo streamRecordingInfo, int addedDisconnectTime) async {
    Database db = await database;

    int oldDisconnectTime = await getDisconnectTime(
        streamRecordingInfo.recordingId, streamRecordingInfo.streamId);

    int count = await db.update(
      'recording_info_${streamRecordingInfo.recordingId}',
      {'disconnect_time': oldDisconnectTime + addedDisconnectTime},
      where: 'stream_id = ?',
      whereArgs: [streamRecordingInfo.streamId],
    );

    print("count of updated rows: $count");
  }

  Future<List<Map>> getStreamRecordingInfo(int recordingId) async {
    Database db = await database;

    List<Map<String, dynamic>> maps =
        await db.query('recording_info_$recordingId');

    return maps;
  }

//!stream recording (table of DATA for each stream in a recording)
  Future<void> createStreamRecording(int recordingId, int streamId) async {
    Database db = await database;
    await db.execute(constructorCreateStreamRecording(recordingId, streamId));
  }

  //insert data into stream recording table
  // pass time and data
  // time is a int in ms
  // data is a double

  Future<void> insertStreamRecordingData(
      int recordingId, int streamId, int timestamp, double data) async {
    Database db = await database;

    await db.execute(
        'INSERT INTO recording_${recordingId}_stream_$streamId (timestamp, data) VALUES ($timestamp, $data)');
  }

  //get stream recording for one datastream
  Future<List<Map>> getStreamRecordingData(
      int recordingId, int streamId) async {
    Database db = await database;

    List<Map<String, dynamic>> maps =
        await db.query('recording_${recordingId}_stream_$streamId');

    return maps;
  }

  //!   BIOZ recordings

  Future<void> createBioZRecording(int recordingId, int streamId) async {
    Database db = await database;
    await db.execute(constructorCreateBioZRecording(recordingId, streamId));
  }

  Future<void> insertBioZRecordingData(int recordingId, int streamId,
      int timestamp, BioZSpectrum spectrum, int numReadings) async {
    Database db = await database;

    for (int i = 0; i < numReadings; i++) {
      await db.execute(
          'INSERT INTO recording_${recordingId}_stream_$streamId (sample_id, timestamp, freq, real, imag) VALUES (NULL, $timestamp, ${spectrum.readings[i].freq}, ${spectrum.readings[i].real}, ${spectrum.readings[i].imag})');
    }
  }

  //!! other

  //pull a list of recordings for a subject
  Future<List<Recording>> getRecordings(int subjectId) async {
    Database db = await database;

    List<Map> result = [];
    try {
      result = await db
          .query('recordings', where: 'subject_id = ?', whereArgs: [subjectId]);
    } on Exception catch (e) {
      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        context: null,
        title: Text("Error getting recordings: $e"),
      );
    }

    List<Recording> recordings = [];
    for (int i = 0; i < result.length; i++) {
      recordings.add(Recording(
        recordingId: result[i]['recording_id'],
        subjectId: result[i]['subject_id'],
        startTime: result[i]['start_time'],
        numberOfStreams: result[i]['number_of_streams'],
      ));
    }

    return recordings;
  }

  //!danger zone
  Future<void> deleteTables() async {
    Database db = await database;
    await db.execute('DROP TABLE subjects');
    await db.execute('DROP TABLE recordings');
  }

  Future<void> createTables() async {
    Database db = await database;
    await db.execute(createSubjects);
    await db.execute(createRecordings);
  }

  Future<void> deleteAndCreateTables() async {
    await deleteTables();
    await createTables();
  }
}
