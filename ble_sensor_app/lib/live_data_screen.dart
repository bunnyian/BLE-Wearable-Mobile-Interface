import 'package:flutter/material.dart';
import 'dart:async';
import 'package:toastification/toastification.dart';
import 'package:intl/intl.dart';

import 'globals.dart' as globals;
import 'database_services.dart';

import 'subject.dart';
import 'multiple_stream_widget.dart';
import 'recording.dart';

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//!!!!! camelCase for DART CODE, snake_case for SQL !!!!!
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// * this is the main user screen that they will look at
// * it will display the live data from the device
// * including: bioimpedance levels, and plotting it on a graph

//todo if subject already exists (names, dob) prompt to verify if they are the same person and not add new entry

//todo select a connected device > a service > a characteristic > read the data

//todo when reading the data, plot it on a graph

//todo as of may30
// need to reset the streams when the user changes the subject
// and when reset is pressed
// accordingly reset the ui buttons available (endRecording set to false, isRecording set to false)

/*
 - allow for lock and unlocked view using scroll controller
 - allow for minimize the graph view
 - wrapped child in expandable view

 ~ data saves to the mysql database
*/

class LiveData extends StatefulWidget {
  @override
  State<LiveData> createState() => _LiveDataState();
}

class _LiveDataState extends State<LiveData>
    with AutomaticKeepAliveClientMixin<LiveData> {
  //! database from database class
  DatabaseServices db = globals.db;

  bool isRecording = false;
  bool endRecording = false;

  //!!!!!! need a way to reset the streams (likely a functio called within multipleStream class

  PreferredSizeWidget appBarMaker(BuildContext context) {
    //app bar that has a text info (enter subject || subject ID)
    //and relevant buttons
    // case 1: no subject selected: search for existing subject, or add new subject
    // case 2: subject selected: view subject info, or start recording
    // case 3: recording: view subject info, or stop recording

    // add subject: simple text form fill
    // search for subject: select which data to search by (name, dob, id)
    // view subject info: display all info entered about subject, when NOT recoridng, allow reset back to case 1
    // start recording: start recording data
    // stop recording: stop recording data
    String subjectInfo;
    if (!globals.subjectSelected) {
      subjectInfo = "Enter Subject before recording data";
    } else {
      subjectInfo = "Subject ID: ${globals.subject.id}";
    }

    Widget searchButton = IconButton(
      onPressed: () {
        //search for subject
        //search by name, dob, id
        //if found, set globals.subjectSelected to true
        //if not found, prompt to add new subject
        print("search button press");
        searchSubjectDialog(context);
      },
      icon: Icon(Icons.search),
    );

    Widget addSubjectButton = IconButton(
      onPressed: () {
        //add new subject
        //prompt for first name, last name, dob, weight, height
        print("add subject button press");

        enterSubjectDialog(context);
      },
      icon: Icon(Icons.add),
    );

    Widget viewSubjectButton = IconButton(
      onPressed: () {
        //view subject info
        //display all info entered about subject
        //when NOT recording, allow reset back to case 1
        print("view subject button press");

        subjectInfoDialog(context);
      },
      icon: Icon(Icons.info_outlined),
    );

    Widget stopRecording = IconButton(
      onPressed: () {
        //stop recording data
        print("stop recording button press");
        controller.stopRecording();
        setState(() {
          isRecording = false;
          endRecording = true;
        });
      },
      icon: Icon(Icons.stop),
    );
    Widget startRecording = IconButton(
      onPressed: () {
        //start recording data
        print("start recording button press");
        setState(() {
          isRecording = true;
          controller.startRecording();
        });
      },
      icon: Icon(Icons.play_arrow),
    );

    Widget resetRecording = IconButton(
      onPressed: () {
        //reset recording data
        print("reset recording button press");
        //need to reset the recording streams
        //!need a new recording id!!!
        controller.resetStreams();
        setState(() {
          isRecording = false;
          endRecording = false;
        });
      },
      icon: Icon(Icons.replay),
    );

    List<Widget> getActions() {
      if (!globals.subjectSelected) {
        return [searchButton, addSubjectButton];
      } else {
        if (isRecording) {
          return [viewSubjectButton, stopRecording];
        } else {
          if (!endRecording) {
            return [viewSubjectButton, startRecording];
          } else {
            return [viewSubjectButton, resetRecording];
          }
        }
      }
    }

    return AppBar(
      title: Text((subjectInfo),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 15)),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      actions: getActions(),
    );
  }

  void getLastAddedSubject() async {
    //get the last added subject
    globals.subject = await db.lastAddedSubject();
    setState(() {
      globals.subjectSelected = true;
    });
    print("subject updated: ${globals.subject}");
    controller.resetStreams();
  }

  void insertThenUpdate(
      String sex, String birthday, double weight, double height) async {
    //insert subject into database
    // used to order the async functions to ensure the write hapens before the read
    await db.insertSubject(sex, birthday, weight, height,
        "Medical History: \n\nConditions and Diagnoses: \n\nMedications: \n\nTherapies: \n\nPersonal Notes: \n\nLast Meal: \n\n");
    getLastAddedSubject();
  }

  void updateSubjectInDb() async {
    //update subject in database
    await db.updateSubject(globals.subject);

    setState(() {});
  }

  Future<dynamic> subjectInfoDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            'Subject Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    Text('Subject ID: ${globals.subject.id}'),
                    Text('Sex: ${globals.subject.sex}'),
                    Text('Date of Birth: ${globals.subject.birthday}'),
                    Text('Weight: ${globals.subject.weight} kg'),
                    Text('Height: ${globals.subject.height} cm'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  viewRecordingsDialog(context);
                },
                child: Text("Recordings")),
            TextButton(
                onPressed: () {
                  editNotesDialog(context);
                },
                child: Text('Notes')),
            changeSubjectDisplayLogic(context),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget changeSubjectDisplayLogic(BuildContext context) {
    if (isRecording == false) {
      return TextButton(
          onPressed: () => setState(() {
                globals.subjectSelected = false;
                Navigator.pop(context);
                controller.resetStreams();
              }),
          child: Text('Change Subject'));
    } else {
      return SizedBox();
    }
  }

  Future<dynamic> viewRecordingsDialog(BuildContext context) {
    //todo get recordings from database for subject, if any
    db.printDatabasePath();
    Future<List<Recording>> listRecordings =
        db.getRecordings(globals.subject.id);

    return showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text("Recordings Log"),
            content: FutureBuilder(
              future: listRecordings,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return recordingsList(snapshot.data);
                } else {
                  return CircularProgressIndicator();
                }
              },
            ),
          );
        });
  }

  Widget recordingsList(recordings) {
    //generate a list of widgets that we can show
    List<Recording> newList = List.from(recordings);

    if (newList.isNotEmpty) {
      print(newList);
      List<Widget> recordingWidgets = [];
      for (var recording in newList) {
        recordingWidgets.add(
          ListTile(
            title: Text(
                "Recording ID: ${recording.recordingId}, ${recording.numberOfStreams} streams"),
            subtitle: Text("Start Time: ${recording.startTime}"),
            onTap: () {
              //todo view the recording
              //show the recording data
              //show the recording info
              //show the recording graph
              print("recording id: ${recording.recordingId}");
              // viewRecordingDialog(context, recording.recordingId);
            },
          ),
        );
      }
      return SingleChildScrollView(
        child: Column(
          children: recordingWidgets,
        ),
      );
    }
    return Text("No recordings found");
  }

  Future<dynamic> enterSubjectDialog(BuildContext context) {
    TextEditingController datePickerController = TextEditingController();
    onTapFunction({required BuildContext context}) async {
      DateTime? pickedDate = await showDatePicker(
        context: context,
        lastDate: DateTime.now(),
        firstDate: DateTime(1900),
        initialDate: DateTime.now(),
      );
      if (pickedDate == null) return;
      datePickerController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
    }

    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (_) {
        var sex = TextEditingController();
        var weight = TextEditingController();
        var height = TextEditingController();
        return AlertDialog(
          title: Text('Subject Information'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: sex,
                    decoration: InputDecoration(hintText: 'Sex (M/F)'),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please enter sex.';
                      }
                      if (value == 'm' || value == 'f') {
                        sex.text = value.toUpperCase();
                      }
                      if (value != 'M' && value != 'F') {
                        return 'Please enter M or F.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: datePickerController,
                    readOnly: true,
                    decoration:
                        const InputDecoration(hintText: "Date of Birth"),
                    onTap: () => onTapFunction(context: context),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please enter a date of birth.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    controller: weight,
                    decoration: const InputDecoration(hintText: "Weight (kg)"),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please enter a height.';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    controller: height,
                    decoration: const InputDecoration(hintText: "Height (cm)"),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please enter a weight.';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                //valid form
                if (formKey.currentState!.validate()) {
                  insertThenUpdate(sex.text, datePickerController.text,
                      double.parse(weight.text), double.parse(height.text));
                  Navigator.pop(context);
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> searchSubjectDialog(BuildContext context) {
    final formKey1 = GlobalKey<FormState>();
    TextEditingController searchController = TextEditingController();
    return showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Search for Subject'),
          content: Form(
            key: formKey1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  keyboardType: TextInputType.number,
                  controller: searchController,
                  decoration:
                      const InputDecoration(hintText: "Enter the Subject ID"),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please enter a value.';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                //search for subject
                //if found, set globals.subjectSelected to true
                //if not found, prompt to add new subject
                if (formKey1.currentState!.validate()) {
                  int id = int.parse(searchController.text);
                  List<Subject> subjects = await db.subjects();
                  bool found = false;
                  for (var subject in subjects) {
                    if (subject.id == id) {
                      found = true;
                      setState(() {
                        globals.subjectSelected = true;
                        globals.subject = subject;
                        controller.resetStreams();
                      });
                      // ignore: use_build_context_synchronously
                      Navigator.pop(context);
                      break;
                    }
                  }
                  if (!found) {
                    toastification.show(
                        title: Text("=== Subject not found ==="),
                        alignment: Alignment.center,
                        type: ToastificationType.error,
                        autoCloseDuration: Duration(seconds: 3));
                  }
                }
              },
              child: Text('Search'),
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> editNotesDialog(BuildContext context) {
    TextEditingController notesController = TextEditingController();
    notesController.text = globals.subject.notes;
    return showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            'Edit Notes',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: TextFormField(
                        style: TextStyle(fontSize: 12),
                        controller: notesController,
                        decoration: InputDecoration(hintText: 'Notes'),
                        maxLines: null,
                        minLines: null,
                        expands: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                //update notes
                setState(() {
                  globals.subject.notes = notesController.text;
                });

                updateSubjectInDb();
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  //! multiple stream widget manager
  // * this will be the main widget that will display the live data

  MultipleStreamController controller = MultipleStreamController();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: appBarMaker(context),
      // body: Placeholder(),
      body: MultipleStream(controller),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
