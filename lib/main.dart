import 'dart:async'; // async support
// json en/decoder

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors/sensors.dart'; // flutter cross-platform sensor suite
import 'package:flutter_appauth/flutter_appauth.dart'; // AppAuth in flutter
//flutter http library
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // package for geolocation
import 'package:camera/camera.dart'; // package for camera
// package for path manipulation
// package for path finding
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dcd.dart' show DCD_client; // DCD(data centric design) definitions

// async main to call our main app state, after retrieving camera
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  // constructor with default attribution to field
  MyApp();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
            value: DCD_client(),
          ),
        ],
        child: MaterialApp(
          title: 'ioSense',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(), // dark theme applied
          home: MyHomePage(),
        ));
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title and appauth object) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  // holds camera descrition

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<double>? _userAccelerometerValues;
  List<double>? _gyroscopeValues;
  _LocationItem? _positionItems;
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final List<StreamSubscription<dynamic>> _streamSubscriptions =
      <StreamSubscription<dynamic>>[];

  bool sendGyro = false, sendLocation = false, sendUserAccelerometer = false;

  bool _sendingData = false;

  void toggleSendData() {
    _sendingData = !_sendingData;
  }

  @override
  Widget build(BuildContext context) {
    final gyroscope =
        _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final userAccelerometer = _userAccelerometerValues
        ?.map((double v) => v.toStringAsFixed(1))
        .toList();
    final location = _positionItems.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DCD Bucket'),
        actions: <Widget>[
          Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {
                  toggleSendData();
                },
                child: Icon(_sendingData ? Icons.pause : Icons.play_arrow),
              )),
          Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: () async {
                await Provider.of<DCD_client>(context, listen: false)
                    .authorize();
                if (Provider.of<DCD_client>(context, listen: false)
                        .thing
                        .name ==
                    '') {
                  Provider.of<DCD_client>(context, listen: false)
                      .FindOrCreateThing('ioSense phone');
                }
              },
              child: Icon(Provider.of<DCD_client>(context).authorized
                  ? Icons.account_box_rounded
                  : Icons.error),
            ),
          ),
        ],
      ),
      body: Container(
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Sensor"),
              Text("Send to Bucket"),
            ]),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('UserAccelerometer: $userAccelerometer'),
                  Checkbox(
                    value: sendUserAccelerometer,
                    onChanged: (newValue) {
                      setState(() {
                        sendUserAccelerometer = newValue!;
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Gyroscope: $gyroscope'),
                  Checkbox(
                    value: sendGyro,
                    onChanged: (newValue) {
                      setState(() {
                        sendGyro = newValue!;
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Text('Location: $location'),
                  ),
                  Checkbox(
                    value: sendLocation,
                    onChanged: (newValue) {
                      // this should make sure the permissions are enabled/requested
                      _handlePermission();
                      setState(() {
                        sendLocation = newValue!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      await Geolocator.openAppSettings();
      await Geolocator.openLocationSettings();
      return false;
    }

    permission = await _geolocatorPlatform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocatorPlatform.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.

        await Geolocator.openAppSettings();
        await Geolocator.openLocationSettings();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.

      await Geolocator.openAppSettings();
      await Geolocator.openLocationSettings();
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    for (StreamSubscription<dynamic> subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();

    _streamSubscriptions.add(gyroscopeEvents.listen((GyroscopeEvent event) {
      if (sendGyro && _sendingData) {
        Provider.of<DCD_client>(context, listen: false)
            .thing
            .updatePropertyByName('GYROSCOPE', [event.x, event.y, event.z]);
      }
      setState(() {
        _gyroscopeValues = <double>[event.x, event.y, event.z];
      });
    }));
    _streamSubscriptions
        .add(userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      if (sendUserAccelerometer && _sendingData) {
        Provider.of<DCD_client>(context, listen: false)
            .thing
            .updatePropertyByName('ACCELEROMETER', [event.x, event.y, event.z]);
      }
      setState(() {
        _userAccelerometerValues = <double>[event.x, event.y, event.z];
      });
    }));
    // Location subscription

    // desired accuracy and the minimum distance change
    // (in meters) before updates are sent to the application - 1m in our case.
    _streamSubscriptions
        .add(Geolocator.getPositionStream().listen((Position event) {
      if (sendLocation && _sendingData) {
        Provider.of<DCD_client>(context, listen: false)
            .thing
            .updatePropertyByName(
                'LOCATION', [event.latitude, event.longitude]);
      }
      setState(() {
        _positionItems = _LocationItem(
            event.latitude, event.longitude, event.speed, event.timestamp);
      });
    }));
  }
}

// taken from https://pub.dev/packages/geolocator/example

enum _PositionItemType {
  permission,
  position,
}

class _PositionItem {
  _PositionItem(this.type, this.displayValue);

  final _PositionItemType type;
  final String displayValue;
}

class _LocationItem {
  _LocationItem(this.lat, this.long, this.speed, this.timestamp);

  final double lat;
  final double long;
  final double speed;
  final DateTime? timestamp;

  @override
  String toString() {
    return 'Latitude: $lat, Longitude: $long, Speed $speed, at $timestamp';
  }
}
