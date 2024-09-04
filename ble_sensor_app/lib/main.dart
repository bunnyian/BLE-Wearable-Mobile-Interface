import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:platform/platform.dart';
import 'dart:async';
import 'package:toastification/toastification.dart';

// data screen imports
import 'ble_screen.dart';
import 'live_data_screen.dart';
import 'export_screen.dart';

// database services import
import 'globals.dart' as globals;

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //wait for db to init

  await globals.db.resetAll(); //reset db
  await globals.db.initDatabase();

  runApp(const MyApp());
}

//* MyApp: main app widget that encompasses everything
//* Monitors Bluetooth state (on/off) and prompts enabling if off
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  final LocalPlatform platform = LocalPlatform();

  // Initialize the Bluetooth state variables
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  // Streams that will continuously update the bluetooth state
  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;

  @override
  void initState() {
    super.initState();
    _adapterStateStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _adapterStateStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adapterState == BluetoothAdapterState.off) {
      () async {
        try {
          if (platform.isAndroid) {
            await FlutterBluePlus.turnOn();
          }
        } catch (e) {
          toastification.show(
            description: Text('Error turning on Bluetooth: $e'),
            type: ToastificationType.error,
            animationDuration: const Duration(seconds: 5),
            alignment: Alignment.center,
          );
        }
        setState(() {});
      }();
    }

    return ToastificationWrapper(
      child: MaterialApp(
        title: 'Sensor Companion App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 0, 97, 176)),
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'Sensor Companion App'),
      ),
    );
  }
}

//* MyHomePage: main page widget that contains the bottom navigation bar
// will cycle to other pages based on the selected index of the bottom nav bar
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  void onTap(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      setState(() {
        _pageController.jumpToPage(index);
      });
    }
  }

  var selectedIndex = 0;

  List<Widget> _pages = <Widget>[
    const BleConnection(),
    LiveData(),
    ExportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sensor Companion App',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: onTap,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'BLE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor),
            label: 'Live Data',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send_to_mobile),
            label: 'Export',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: onTap,
      ),
    );
  }
}
