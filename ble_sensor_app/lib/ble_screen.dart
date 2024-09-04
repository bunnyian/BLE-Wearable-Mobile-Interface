import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:toastification/toastification.dart';

//Status of BLE Screen

/* 
- scan devices
- manages permissions
- connect, disconnect from devices
=> next screen: LiveData, start by discovering services
*/

//* This screen manages scanning, connecting, and disconnecting from BLE devices
//* it will initiate bluetooth request and verify if the device supports bluetooth
// (might be redundant with the main.dart>MyApp widget, can refactor later)
class BleConnection extends StatefulWidget {
  const BleConnection({super.key});

  @override
  State<BleConnection> createState() => _BleConnectionState();
}

class _BleConnectionState extends State<BleConnection> {
  startBle() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    } else {
      print("Bluetooth is supported by this device");
    }
    // handle bluetooth on & off
    // note: for iOS the initial state is typically BluetoothAdapterState.unknown
    // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
  }

  @override
  void initState() {
    startBle();
    // first, check if bluetooth is supported by your hardware
// Note: The platform is initialized on the first call to any FlutterBluePlus method.

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scanning(); // always allow scanning
    // todo allow for connecting multiple sensors at once
  }
}

class Scanning extends StatefulWidget {
  const Scanning({super.key});

  @override
  State<Scanning> createState() => _ScanningState();
}

class _ScanningState extends State<Scanning>
    with AutomaticKeepAliveClientMixin<Scanning> {
  List<ScanResult> _scanResults = [];

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothAdapterState> _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
    });
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
    }, onError: (e) {
      print("error in scanResultsSubscription: $e");
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    _adapterStateSubscription.cancel();
    print("Scanning disposed");
    print("Scanning disposed");
    print("Scanning disposed");
    print("Scanning disposed");
    print("Scanning disposed");
    print("Scanning disposed");
    print("Scanning disposed");
    print("Scanning disposed");
    super.dispose();
  }

  Future onScanPressed() async {
    if (_adapterState != BluetoothAdapterState.on) {
      toastification.show(
          title: Text("Cannot access Bluetooth: $_adapterState"),
          alignment: Alignment.center,
          type: ToastificationType.error,
          autoCloseDuration: Duration(seconds: 3));
      return;
    }

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      // withNames: ['HRSTM'],
    ).catchError((e) {
      toastification.show(
          title: Text("Scanning Error: ${_adapterState.toString()}"),
          alignment: Alignment.center,
          type: ToastificationType.error,
          autoCloseDuration: Duration(seconds: 3));
    });
    if (mounted) {
      setState(() {});
    }
  }

  Future onStopPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      print("System Devices Error: $e");
    }
  }

  void onConnectPressed(ScanResult result) async {
    (connectHelper(result)).catchError((exception) {
      print("Connection Error: $exception");
      // toastification.show(
      //     title: Text("Connection Error: $exception"),
      //     alignment: Alignment.center,
      //     type: ToastificationType.error,
      //     autoCloseDuration: Duration(seconds: 3));
    });

    //todo convert to setstate after future compoletes
  }

  Future<void> connectHelper(ScanResult result) async {
    StreamSubscription<BluetoothConnectionState> connectionStream =
        result.device.connectionState.listen((event) {
      if (event == BluetoothConnectionState.connected) {
        print("CONNECTED CONNECTED CONNECTED to ${result.device.platformName}");
        if (Platform.isAndroid) {
          result.device.requestMtu(512);
        }
      } else {
        print(
            "DISCONNECTED DISCONNECTED DISCONNECTED from ${result.device.platformName}");
      }
      if (mounted) {
        setState(() {});
      }
    });
    try {
      result.device
          .connect(
              timeout: const Duration(seconds: 30),
              mtu: null,
              autoConnect: true)
          .catchError((e) {
        toastification.show(
            title: Text("Connection Error: $e"),
            alignment: Alignment.center,
            type: ToastificationType.error,
            autoCloseDuration: Duration(seconds: 3));
      });
    } catch (e) {
      print("Connection Error: $e");
    }
    // finally {
    //   if (mounted) {
    //     setState(() {});
    //   }
    // }
  }

  void onDisconnectPressed(BluetoothDevice device) async {
    device.disconnect().then((value) {
      if (mounted) {
        setState(() {});
      }
    }).catchError((e) {
      toastification.show(
          title: Text("Disconnection Error: $e"),
          alignment: Alignment.center,
          type: ToastificationType.error,
          autoCloseDuration: Duration(seconds: 3));
    });
  }

  Widget buildScanButton(BuildContext context) {
    if (FlutterBluePlus.isScanningNow) {
      return ElevatedButton.icon(
        label: Text("Stop Scanning", style: TextStyle(color: Colors.black)),
        icon: const Icon(Icons.stop, color: Colors.black),
        onPressed: onStopPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
      );
    } else {
      return ElevatedButton.icon(
        label: Text("Scan for Sensor", style: TextStyle(color: Colors.black)),
        icon: const Icon(Icons.search, color: Colors.black),
        onPressed: onScanPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
      );
    }
  }

  void connectToast() {
    toastification.show(
        title: Text("Connecting to Sensor"),
        alignment: Alignment.center,
        type: ToastificationType.info,
        autoCloseDuration: Duration(seconds: 3));
  }

  Text deviceTitle(BluetoothDevice device) {
    if (device.platformName == "") {
      print("Unamed Device found");
      return Text("Unamed Device",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontStyle: FontStyle.italic,
          ));
    } else {
      return Text(device.platformName,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.bold,
          ));
    }
  }

  //sort the devices by name
  void sortDevices() {
    // remove duplicates
    _scanResults = _scanResults.toSet().toList();

    //keep connected devices at top, sort by name with nonempty names first
    _scanResults.sort((a, b) {
      if (a.device.isConnected && !b.device.isConnected) {
        return -1;
      } else if (!a.device.isConnected && b.device.isConnected) {
        return 1;
      } else {
        return b.device.platformName.compareTo(a.device.platformName);
      }
    });
  }

  void addConnectedDevicesToList() async {
    //check all devices in the scan results list are connected
    //list is _scanResultsConnectedDevices
    for (var device in FlutterBluePlus.connectedDevices) {
      try {
        _scanResults.add(ScanResult(
            device: device,
            rssi: 0,
            timeStamp: DateTime.now(),
            advertisementData: AdvertisementData(
              advName: device.platformName,
              manufacturerData: {},
              serviceData: {},
              serviceUuids: [],
              txPowerLevel: 0,
              appearance: 0,
              connectable: false,
            )));
      } catch (e) {
        //not connected, remove from list
      }
    }
  }

  SizedBox connectButtonMaker(BuildContext context, ScanResult device) {
    bool connected = false;

    try {
      connected = device.device.isConnected;
    } catch (e) {
      //not connected, move on
    }

    String connectText = connected ? "Disconnect" : "Connect";
    Icon connectIcon = connected
        ? Icon(Icons.bluetooth_connected,
            color: Theme.of(context).colorScheme.onSecondary)
        : Icon(Icons.bluetooth,
            color: Theme.of(context).colorScheme.onSecondary);

    Color backgroundColor = connected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;

    Color textColor = connected
        ? Theme.of(context).colorScheme.onSecondary
        : Theme.of(context).colorScheme.onPrimary;

    Function onPressed = connected
        ? () => onDisconnectPressed(device.device)
        : () => onConnectPressed(device);
    return SizedBox(
      width: 145,
      height: 90,
      child: Center(
        child: SizedBox(
          width: 135,
          height: 80,
          child: ElevatedButton(
            onPressed: () => onPressed(),
            style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(connectIcon.icon, color: textColor),
                Text(connectText, style: TextStyle(color: textColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    addConnectedDevicesToList();
    sortDevices();
    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Scan for Sensor devices. Tap to connect.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 15)),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        body: ListView(
          children: <Widget>[
            for (var device in _scanResults)
              Card(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Row(
                    children: [
                      connectButtonMaker(context, device),
                      Expanded(
                        child: ListTile(
                          isThreeLine: true,
                          title: deviceTitle(device.device),
                          subtitle: Text(
                              "${device.device.remoteId}\n${device.rssi.toString()} dBm",
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer)),
                          // onTap: () => onConnectPressed(device.device),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: buildScanButton(context),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
