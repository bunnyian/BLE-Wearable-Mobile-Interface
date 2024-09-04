//TODO ensure controller functions only called when appropriate ie. streams.isNotEmtpy, isRecording, endRecording

import 'dart:math';
import 'package:scidart/numdart.dart';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:gap/gap.dart';

import 'globals.dart' as globals;
import 'database_services.dart';

import 'recording.dart'; // library of recordings (similar to Subjects)

//for a specific recording session
import 'stream_recording_info.dart'; //metadata of the stream
//data of the stream

import 'single_stream.dart'; //data class for a single stream
import 'package:fl_chart/fl_chart.dart';

int WINDOWSIZE_MS = 30000;
int BIOZ_WINDOWSIZE_MS = 2 * 60000;
int IDEAL_Z_FREQ_KHZ = 50;
double PADDING_PERCENT = 0.1;

class MultipleStreamController {
  late Future<void> Function() startRecording; //delay to start db
  late void Function() stopRecording; //immediate stop
  late Future<void> Function() resetStreams; //rebuilds all streams
}

class MultipleStream extends StatefulWidget {
  final MultipleStreamController controller;

  MultipleStream(this.controller);

  @override
  // ignore: no_logic_in_create_state
  State<MultipleStream> createState() => _MultipleStreamState(controller);
}

class _MultipleStreamState extends State<MultipleStream>
    with AutomaticKeepAliveClientMixin<MultipleStream> {
  _MultipleStreamState(MultipleStreamController controller) {
    controller.startRecording = startRecording;
    controller.stopRecording = stopRecording;
    controller.resetStreams = resetStreams;
  }

  bool isRecording = false;
  bool endRecording = false;

  DatabaseServices db = globals.db;

  List<SingleStream> streams = [];

  late Timer timer;

  List<(BluetoothCharacteristic, BluetoothService)>
      selectedCharacteristicsAndServices = [];

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      //rebuild stream widgets every second
      if (endRecording == false) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();

    print("disposing multiple stream widget");
    print("disposing multiple stream widget");
    print("disposing multiple stream widget");
    print("disposing multiple stream widget");
    print("disposing multiple stream widget");
    print("disposing multiple stream widget");
    print("disposing multiple stream widget");
    print("disposing multiple stream widget");
    super.dispose();
  }

  void addStream(
      BluetoothDevice device,
      BluetoothService service,
      BluetoothCharacteristic characteristic,
      String streamName,
      String streamUnits,
      bool isBioZ) async {
    int recordingId = await db.getNextRecordingId();
    int streamId = streams.length + 1;

    StreamRecordingInfo streamRecordingInfo = StreamRecordingInfo(
      subjectId: globals.subject.id,
      recordingId: recordingId,
      streamId: streamId,
      device: device,
      service: service,
      characteristic: characteristic,
      deviceName: device.platformName,
      serviceName: service.uuid.toString(),
      characteristicName: characteristic.uuid.toString(),
      streamName: streamName,
      streamUnits: streamUnits,
      isBioZ: isBioZ,
    );

    SingleStream newStream = SingleStream(streamRecordingInfo);

    setState(() {
      streams.add(newStream);
    });
  }

  void removeStream(int streamId) {
    setState(() {
      streams.removeAt(streamId - 1);
    });
  }

  Future<void> startRecording() async {
    Recording newRecording = Recording(
      recordingId: await db.getNextRecordingId(),
      subjectId: globals.subject.id,
      startTime: DateTime.now().toIso8601String(),
      numberOfStreams: streams.length,
    );
    //entry in table Recordings to note this recording started
    await db.insertRecording(newRecording);

    //entry in table Recordings for metadata
    await db.createRecordingInfo(newRecording.recordingId);
    print("RECORDING INFO TABLE CREATED");
    print("RECORDING INFO TABLE CREATED");
    print("RECORDING INFO TABLE CREATED");
    print("RECORDING INFO TABLE CREATED");
    print("RECORDING INFO TABLE CREATED");

    //start streams recording
    for (SingleStream stream in streams) {
      stream.startRecording();
    }

    setState(() {
      isRecording = true;
      endRecording = false;
    });
  }

  void stopRecording() {
    for (SingleStream stream in streams) {
      stream.stopRecording();
    }

    setState(() {
      isRecording = false;
      endRecording = true;
    });
  }

  Future<void> resetStreams() async {
    List<SingleStream> newStreams = [];
    StreamRecordingInfo newStreamRecordingInfo;
    int recordingId = await db.getNextRecordingId();

    int streamId = 0;
    for (SingleStream stream in streams) {
      streamId++;
      newStreamRecordingInfo = StreamRecordingInfo(
          recordingId: recordingId,
          streamId: streamId,
          subjectId: globals.subject.id,
          device: stream.streamRecordingInfo.device,
          service: stream.streamRecordingInfo.service,
          characteristic: stream.streamRecordingInfo.characteristic,
          deviceName: stream.streamRecordingInfo.deviceName,
          serviceName: stream.streamRecordingInfo.serviceName,
          characteristicName: stream.streamRecordingInfo.characteristicName,
          streamName: stream.streamRecordingInfo.streamName,
          streamUnits: stream.streamRecordingInfo.streamUnits,
          isBioZ: stream.streamRecordingInfo.isBioZ);

      SingleStream newStream = SingleStream(newStreamRecordingInfo);
      newStreams.add(newStream);

      stream.dispose();
    }

    // setState(() {
    //   streams = [];
    // });

    // //1s delay to reset streams
    // await Future.delayed(Duration(seconds: 1));

    setState(() {
      streams = List.from(newStreams);
      isRecording = false;
      endRecording = false;
    });
  }

  //!!! WIDGITs

  void onManageStreamPressed() {
    //show dialog to add or remove a stream

    if (streams.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Manage Streams',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text("Add a new stream or remove one"),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onRemoveStreamPressed();
                },
                child: Text('Remove Stream'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  selectFromStreamsList();
                },
                child: Text('Select Streams from List'),
              )
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Manage Streams'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text("Add a new stream or remove one"),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  selectFromStreamsList();
                },
                child: Text('Select Streams from List'),
              )
            ],
          );
        },
      );
    }
  }

  ElevatedButton? buildFloatingActionButton() {
    if (isRecording) {
      return null; //when recording, nothing should be shown
    } else if (endRecording) {
      return null; //when recording has ended, nothing should be shown
      //streams can be rebuilt first
    } else {
      //when not recording, show the floating action button
      return ElevatedButton.icon(
        label: Text(
          'Manage Streams',
          style: TextStyle(color: Colors.black),
        ),
        icon: Icon(
          Icons.create_outlined,
          color: Colors.black,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
        ),
        onPressed: () {
          onManageStreamPressed();
        },
      );
    }
  }

//TODO: implement alternative path to select streams
//TODO: 1) select from checklist the streams you want
//TODO: LIST form which allows entering names for each stream and units
//TODO: create the streams based on the checklist using the names and units entered

  Future<List<(BluetoothCharacteristic, BluetoothService)>>
      getNotifiableCharacteristics() async {
    List<(BluetoothCharacteristic, BluetoothService)>
        notifiableCharacteristics = [];

    List<BluetoothDevice> connectedDevices = FlutterBluePlus.connectedDevices;

    List<BluetoothService> services = [];

    for (BluetoothDevice device in connectedDevices) {
      services = await device.discoverServices();

      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.properties.notify) {
            notifiableCharacteristics.add((characteristic, service));
          }
        }
      }
    }

    return notifiableCharacteristics;
  }

  void selectFromStreamsList() {
    late Future<List<(BluetoothCharacteristic, BluetoothService)>>
        notifiableCharacteristics = getNotifiableCharacteristics();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, StateSetter dialogSetState) {
          return AlertDialog(
            title: Text('Select Streams'),
            content: FutureBuilder(
                future: notifiableCharacteristics,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Scaffold(
                      body: ListView.builder(
                        itemCount: snapshot.data?.length,
                        itemBuilder: (context, index) {
                          return CheckboxListTile(
                            value: selectedCharacteristicsAndServices
                                .contains(snapshot.data?[index]),
                            title: Text(
                                "${snapshot.data?[index].$1.device.platformName} — ${snapshot.data?[index].$1.serviceUuid.toString()} — ${snapshot.data?[index].$1.characteristicUuid.toString()}"),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (bool? value) {
                              if (value == true) {
                                dialogSetState(() {
                                  selectedCharacteristicsAndServices
                                      .add(snapshot.data![index]);
                                  print(
                                      "selected: ${snapshot.data![index].$1}");
                                });
                              } else {
                                dialogSetState(() {
                                  selectedCharacteristicsAndServices
                                      .remove(snapshot.data![index]);
                                });
                                print(
                                    "deselected: ${snapshot.data![index].$1}");
                              }
                            },
                          );
                        },
                      ),
                    );
                  }
                  return CircularProgressIndicator();
                }),
            actions: <Widget>[
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Cancel")),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    List<(BluetoothCharacteristic, BluetoothService)>
                        tempStorage =
                        List.from(selectedCharacteristicsAndServices);
                    selectedCharacteristicsAndServices = [];
                    enterSteamsListNamesUnits(tempStorage);
                  },
                  child: Text("Select Streams")),
            ],
          );
        });
      },
    );
  }

  void enterSteamsListNamesUnits(
      List<(BluetoothCharacteristic, BluetoothService)>
          characteristicsAndServices) {
    //Popup with text form for each stream
    // display them by Characteristic uuid

    List<String> streamNames = [];
    List<TextEditingController> streamNameControllers = [];
    List<TextEditingController> streamUnitControllers = [];
    List<bool> bioZConfig = [];

    for ((BluetoothCharacteristic, BluetoothService) tuple
        in characteristicsAndServices) {
      streamNames.add(
          "${tuple.$1.device.platformName} - ${tuple.$1.characteristicUuid.toString()}");
      streamNameControllers.add(TextEditingController());
      streamUnitControllers.add(TextEditingController());
      bioZConfig.add(false);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Stream Names and Units'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Form(
                  child: Column(
                    key: GlobalKey<FormState>(),
                    children: List.generate(
                        streamNames.length,
                        (index) => Column(
                              children: [
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      children: [
                                        Text(streamNames[index]),
                                        TextFormField(
                                          controller:
                                              streamNameControllers[index],
                                          decoration: InputDecoration(
                                              hintText: 'Enter Stream Name'),
                                        ),
                                        TextFormField(
                                          controller:
                                              streamUnitControllers[index],
                                          decoration: InputDecoration(
                                              hintText: 'Enter Stream Units'),
                                        ),
                                        StatefulBuilder(builder: (context,
                                            StateSetter checkSetState) {
                                          return CheckboxListTile(
                                            title: Text("BioZ Signal"),
                                            value: bioZConfig[index],
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            onChanged: (bool? value) {
                                              bioZConfig[index] = value!;
                                              checkSetState(() {});
                                            },
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                                Gap(8),
                              ],
                            )),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                int prevStreamsLength = streams.length;
                for (int i = 0; i < characteristicsAndServices.length; i++) {
                  String streamName, streamUnits;
                  if (streamNameControllers[i].text.isNotEmpty) {
                    streamName = streamNameControllers[i].text;
                  } else {
                    streamName = "Stream ${prevStreamsLength + i + 1}";
                  }
                  if (streamUnitControllers[i].text.isNotEmpty) {
                    streamUnits = streamUnitControllers[i].text;
                  } else {
                    streamUnits = "Unit";
                  }

                  addStream(
                      characteristicsAndServices[i].$1.device,
                      characteristicsAndServices[i].$2,
                      characteristicsAndServices[i].$1,
                      streamName,
                      streamUnits,
                      bioZConfig[i]);
                }
              },
              child: Text("Add Streams"),
            ),
          ],
        );
      },
    );
  }

  void onRemoveStreamPressed() {
    //list of current streams as dropdown
    List<DropdownMenuEntry<int>> dropdownEntries = [];
    for (var stream in streams) {
      dropdownEntries.add(DropdownMenuEntry<int>(
          value: stream.streamRecordingInfo.streamId,
          label: stream.streamRecordingInfo.streamName));
    }

    //controller
    var streamIdController = TextEditingController();

    //show dialog to remove a stream
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove a Stream'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownMenu<int>(
                initialSelection: dropdownEntries.first.value,
                controller: streamIdController,
                dropdownMenuEntries: dropdownEntries,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                //get stream id of selected stream
                int streamId = dropdownEntries
                    .firstWhere(
                        (element) => element.label == streamIdController.text)
                    .value;

                removeStream(streamId);
                resetStreams();
              },
              child: Text('Remove Stream'),
            ),
          ],
        );
      },
    );
  }

  (double, double) minMaxYGenerator(SingleStream stream) {
    double min = 0;
    double max = 0;

    for (int i = stream.streamRecording.data.length - 1; i >= 0; i--) {
      if (stream.streamRecording.timestamps[i] <
          stream.streamRecording.timestamps.last - WINDOWSIZE_MS) {
        break;
      } else {
        if (stream.streamRecording.data[i] < min) {
          min = stream.streamRecording.data[i];
        }
        if (stream.streamRecording.data[i] > max) {
          max = stream.streamRecording.data[i];
        }
      }
    }

    double range = max - min;
    //scaling
    min -= range * PADDING_PERCENT;
    max += range * PADDING_PERCENT;

    return (min, max);
  }

  Widget biozECW(SingleStream stream) {
    //find closest available frequency to IDEA_Z_FREQ_KHZ
    List<FlSpot> spotsList = spotsListGenerator(stream);

    double minY, maxY;
    if (spotsList.isNotEmpty) {
      minY = spotsList[0].y;
      maxY = spotsList[0].y;

      for (FlSpot spot in spotsList) {
        if (spot.y < minY) {
          minY = spot.y;
        }
        if (spot.y > maxY) {
          maxY = spot.y;
        }
      }

      double padding = 1.05;

      maxY = maxY * padding;
      minY = minY / padding;
    } else {
      minY = 0;
      maxY = 0;
    }

    return AspectRatio(
      aspectRatio: 3.0,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: LineChart(
          duration: const Duration(milliseconds: 0),
          LineChartData(
            clipData: FlClipData.all(),
            titlesData: FlTitlesData(
              show: true,
              leftTitles:
                  AxisTitles(axisNameSize: 30, axisNameWidget: Text("ECW (L)")),
              topTitles: AxisTitles(
                axisNameSize: 30,
                axisNameWidget: Text("Time (HH:MM:SS)"),
              ),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      interval: Duration(hours: 999)
                          .inSeconds
                          .toDouble(), //todo lazy fix
                      getTitlesWidget: getTimeLabels,
                      reservedSize: 25)),
            ),
            minX: minTimeGenerator(stream).toDouble(),
            maxX: minTimeGenerator(stream).toDouble() + BIOZ_WINDOWSIZE_MS,
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spotsList,
                isCurved: false,
                color: Colors.black,
                barWidth: 1,
                isStrokeCapRound: true,
                preventCurveOverShooting: true,
                belowBarData: BarAreaData(show: false),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (p0, p1, p2, p3) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double getECW(SingleStream stream, int i, int lowestFreqIndex) {
    double r0 = stream.bioZRecording.spectra[i].readings[lowestFreqIndex].real;

    double effectiveResistivityMale =
        214; //ohm-cm //values from https://doi.org/10.1093/ajcn/70.5.847
    double effectiveResistivityFemale = 206; //ohm-cm
    double bodyShapeFactor = 4.3; //dimensionless
    double bodyDensity = 1.05; //kg/L

    double height = globals.subject.height; //cm
    double weight = globals.subject.weight; //kg
    double effectiveResistivity;

    if (globals.subject.sex == "M") {
      effectiveResistivity = effectiveResistivityMale;
    } else {
      effectiveResistivity = effectiveResistivityFemale;
    }

    double extraCellularWater = 0.01 *
        pow(
            ((effectiveResistivity *
                    bodyShapeFactor *
                    pow(height, 2) *
                    pow(weight, 0.5)) /
                (r0 * pow(bodyDensity, 0.5))),
            (2 / 3));

    return extraCellularWater;
  }

  Widget getColeColeWidget(SingleStream stream) {
    List<FlSpot> coleColeSpots = [];
    List<double> coleColeX = [];
    List<double> coleColeY = [];
    List<FlSpot> trendLine = [];

    if (stream.bioZRecording.spectra.isNotEmpty) {
      for (int i = 0;
          i < stream.bioZRecording.spectra.last.readings.length;
          i++) {
        double resistance = stream.bioZRecording.spectra.last.readings[i].real;
        double reactance = stream.bioZRecording.spectra.last.readings[i].imag;

        coleColeSpots.add(FlSpot(resistance, reactance));
        coleColeX.add(resistance);
        coleColeY.add(reactance);
      }

      if (true) {
        const int degree = 2;
        var x = Array(coleColeX);
        var y = Array(coleColeY);

        PolyFit poly = PolyFit(x, y, degree);

        var coeffs = poly.coefficients();

        // a + bx + cx^2
        double c = coeffs[0];
        double b = coeffs[1];
        double a = coeffs[2];

        for (int i = coleColeX[0].toInt(); i < coleColeX.last.toInt(); i++) {
          trendLine.add(FlSpot(i.toDouble(), a + b * i + c * i * i));
        }
      }
    }
    return AspectRatio(
      aspectRatio: 1.4,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: LineChart(
          duration: const Duration(milliseconds: 0),
          LineChartData(
            clipData: FlClipData.all(),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: AxisTitles(
                  axisNameSize: 30, axisNameWidget: Text("-Reactance (Ω)")),
              topTitles: AxisTitles(
                axisNameSize: 30,
                axisNameWidget: Text("Resistance (Ω)"),
              ),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 25)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: coleColeSpots,
                barWidth: 0,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (p0, p1, p2, p3) => FlDotCirclePainter(
                    radius: 5,
                    color: Colors.blue,
                  ),
                ),
              ),
              LineChartBarData(
                spots: trendLine,
                isCurved: true,
                color: Colors.red,
                barWidth: 3,
                isStrokeCapRound: true,
                preventCurveOverShooting: true,
                dotData: FlDotData(
                  show: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getBioZWidget(SingleStream stream) {
    if (stream.graphOptionsSelected[0]) {
      if (globals.subjectSelected) {
        return biozECW(stream);
      } else {
        return AspectRatio(
          aspectRatio: 3.0,
          child: Card(
            child: Center(child: Text("Please enter subject info to see ECW")),
          ),
        );
      }
    } else {
      return getColeColeWidget(stream);
    }
  }

  Widget buildStreamWidget(SingleStream stream) {
    if (stream.streamRecordingInfo.isBioZ == false) {
      double data = 0;
      int timestamp = 0;

      try {
        //in case of not yet initialized
        if (stream.streamRecording.data.isEmpty) {
        } else {
          data = stream.streamRecording.data.last;
          timestamp = stream.streamRecording.timestamps.last;
        }
      } catch (e) {
        print("Error: $e");
      }

      String timestampString = timestamp.toString();

      int disconnectedTime = stream.streamRecordingInfo.disconnectTime;
      if (stream.startedDisconnectMs != 0) {
        disconnectedTime +=
            DateTime.now().millisecondsSinceEpoch - stream.startedDisconnectMs;
      }

      (double, double) minMax = minMaxYGenerator(stream);

      return ExpansionTile(
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
            "${stream.streamRecordingInfo.streamId}: ${stream.streamRecordingInfo.streamName} — (${stream.streamRecordingInfo.deviceName}/${stream.streamRecordingInfo.serviceName}/${stream.streamRecordingInfo.characteristicName})"),
        children: <Widget>[
          Text(
              'Last data point: $data - Last data time (ms): $timestampString - Disconnected Time (ms): ${disconnectedTime}'),
          AspectRatio(
            aspectRatio: 3.0,
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: LineChart(
                duration: const Duration(milliseconds: 0),
                LineChartData(
                  clipData: FlClipData.all(),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                        axisNameSize: 30,
                        axisNameWidget: Text(
                            "${stream.streamRecordingInfo.streamName} (${stream.streamRecordingInfo.streamUnits})")),
                    topTitles: AxisTitles(
                      axisNameSize: 30,
                      axisNameWidget: Text("Time (HH:MM:SS)"),
                    ),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            interval: Duration(hours: 999)
                                .inSeconds
                                .toDouble(), //todo lazy fix
                            getTitlesWidget: getTimeLabels,
                            reservedSize: 25)),
                  ),
                  minX: minTimeGenerator(stream).toDouble(),
                  maxX: minTimeGenerator(stream).toDouble() + WINDOWSIZE_MS,
                  minY: minMax.$1,
                  maxY: minMax.$2,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spotsListGenerator(stream),
                      isCurved: false,
                      color: Colors.black,
                      barWidth: 1,
                      isStrokeCapRound: true,
                      preventCurveOverShooting: true,
                      belowBarData: BarAreaData(show: false),
                      dotData: FlDotData(
                        show: false,
                        getDotPainter: (p0, p1, p2, p3) => FlDotCirclePainter(
                          radius: 5,
                          color: Colors.blueAccent,
                          strokeWidth: 0,
                          strokeColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      int timestamp = 0;

      try {
        //in case of not yet initialized
        if (stream.bioZRecording.timestamps.isNotEmpty) {
          timestamp = stream.bioZRecording.timestamps.last;
        }
      } catch (e) {
        print("Error: $e");
      }

      String timestampString = timestamp.toString();

      int disconnectedTime = stream.streamRecordingInfo.disconnectTime;
      if (stream.startedDisconnectMs != 0) {
        disconnectedTime +=
            DateTime.now().millisecondsSinceEpoch - stream.startedDisconnectMs;
      }

      //TODO: Padding min max for Y for BioZ
      // (double, double) minMax = minMaxYGenerator(stream);

      return StatefulBuilder(builder: (context, StateSetter expansionSetState) {
        return ExpansionTile(
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
              "${stream.streamRecordingInfo.streamId}: ${stream.streamRecordingInfo.streamName} — (${stream.streamRecordingInfo.deviceName}/${stream.streamRecordingInfo.serviceName}/${stream.streamRecordingInfo.characteristicName})"),
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToggleButtons(
                  direction: Axis.horizontal,
                  isSelected: stream.graphOptionsSelected,
                  onPressed: (index) => {
                    expansionSetState(() {
                      for (int buttonIndex = 0;
                          buttonIndex < stream.graphOptionsSelected.length;
                          buttonIndex++) {
                        if (buttonIndex == index) {
                          stream.graphOptionsSelected[buttonIndex] = true;
                        } else {
                          stream.graphOptionsSelected[buttonIndex] = false;
                        }
                      }
                    })
                  },
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  selectedBorderColor: Colors.blue,
                  selectedColor: Colors.blue,
                  children: stream.graphOptions,
                ),
                Gap(15),
                Text('Up:Down - $timestampString:${disconnectedTime}'),
              ],
            ),
            getBioZWidget(stream),
          ],
        );
      });
    }
  }

  SideTitleWidget getTimeLabels(double value, TitleMeta titleMeta) {
    Duration time = Duration(milliseconds: value.toInt());

    String timeString;

    if (time < Duration(hours: 1)) {
      timeString = time.toString().substring(2, 7);
    } else {
      timeString = time.toString().substring(0, 7);
    }

    return SideTitleWidget(
      axisSide: AxisSide.bottom,
      angle: 0,
      child: Text(timeString),
    );
  }

  int minTimeGenerator(SingleStream stream) {
    if (stream.streamRecordingInfo.isBioZ == false) {
      if (stream.streamRecording.timestamps.isNotEmpty) {
        int lastTimestamp = stream.streamRecording.timestamps.last;

        for (int i = stream.streamRecording.data.length - 1; i >= 0; i--) {
          if (stream.streamRecording.timestamps[i] <
              lastTimestamp - WINDOWSIZE_MS) {
            return stream.streamRecording.timestamps[i];
          }
        }
      }
    } else {
      if (stream.bioZRecording.timestamps.isNotEmpty) {
        int lastTimestamp = stream.bioZRecording.timestamps.last;

        for (int i = stream.bioZRecording.timestamps.length - 1; i >= 0; i--) {
          if (stream.bioZRecording.timestamps[i] <
              lastTimestamp - BIOZ_WINDOWSIZE_MS) {
            return stream.bioZRecording.timestamps[i];
          }
        }
      }
    }

    return 0;
  }

  List<FlSpot> spotsListGenerator(SingleStream stream) {
    List<FlSpot> spotsList = [];

    if (stream.streamRecordingInfo.isBioZ == false) {
      if (stream.streamRecording.timestamps.isNotEmpty) {
        int lastTimestamp = stream.streamRecording.timestamps.last;

        for (int i = stream.streamRecording.data.length - 1; i >= 0; i--) {
          if (stream.streamRecording.timestamps[i] <
              lastTimestamp - WINDOWSIZE_MS) {
            break;
          } else {
            //add spot to front of list
            spotsList.insert(
                0,
                FlSpot((stream.streamRecording.timestamps[i]).toDouble(),
                    stream.streamRecording.data[i]));
          }
        }

        print("length of spots list: ${spotsList.length}");
      }
    } else {
      int lowestFreq = 9999; //find R0
      int lowestFreqIndex = 0;

      if (stream.bioZRecording.spectra.isNotEmpty) {
        for (int i = 0;
            i < stream.bioZRecording.spectra.last.readings.length;
            i++) {
          if (stream.bioZRecording.spectra.last.readings[i].freq < lowestFreq) {
            lowestFreq = stream.bioZRecording.spectra.last.readings[i].freq;
            lowestFreqIndex = i;
          }
        }
      }

      List<int> timestamps = stream.bioZRecording.timestamps;
      List<double> ECWs = [];

      for (int i = 0; i < timestamps.length; i++) {
        ECWs.add(getECW(stream, i, lowestFreqIndex));
        // ECWs.add(5);
      }

      for (int i = timestamps.length - 1; i >= 0; i--) {
        if (timestamps[i] < timestamps.last - BIOZ_WINDOWSIZE_MS) {
          break;
        } else {
          //add spot to front of list
          spotsList.insert(0, FlSpot(timestamps[i].toDouble(), ECWs[i]));
        }
      }
    }

    spotsList.sort((a, b) => a.x.compareTo(b.x));
    return spotsList;
  }

  //generate a stateless widget that displays the stream data based on the stream data
  //rebuilds as the parents do

  List<Widget> buildStreamWidgets() {
    List<Widget> streamWidgets = [];

    for (SingleStream stream in streams) {
      streamWidgets.add(buildStreamWidget(stream));
    }

    return streamWidgets;
  }

  //ui
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      floatingActionButton: buildFloatingActionButton(),
      body: SingleChildScrollView(
        child: Column(
          children: buildStreamWidgets(),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
