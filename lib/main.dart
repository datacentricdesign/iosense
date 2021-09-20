import 'dart:async'; // async support
// json en/decoder

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart'; // flutter cross-platform sensor suite
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart'; // package for geolocation
import 'dcd.dart' show DCD_client; // DCD(data centric design) definitions

// async main to call our main app state, after retrieving camera
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of the available cameras on the device.

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
          theme: ThemeData.light(), // dark theme applied
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
  List<double>? _magnetometerValues;
  final Location location = Location();

  LocationData? _location;
  StreamSubscription<LocationData>? _locationSubscription;
  final List<StreamSubscription<dynamic>> _streamSubscriptions =
      <StreamSubscription<dynamic>>[];

  bool sendGyro = false,
      sendLocation = false,
      sendBearing = false,
      sendAltitude = false,
      sendUserAccelerometer = false,
      sendMagnet = false;

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
    final magnetometer =
        _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final location = _location;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ioSense'),
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
                  await Provider.of<DCD_client>(context, listen: false)
                      .FindOrCreateThing('ioSense phone2');
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sensor'),
                    Text('Send to Bucket'),
                  ]),
            ),
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
                  Text('Magnetometer: $magnetometer'),
                  Checkbox(
                    value: sendMagnet,
                    onChanged: (newValue) {
                      setState(() {
                        sendMagnet = newValue!;
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
                    child: Text('Location: ${location.toString()}'),
                  ),
                  Checkbox(
                    value: sendLocation,
                    onChanged: (newValue) {
                      // this should make sure the permissions are enabled/requested
                      // _handlePermission();
                      setState(() {
                        sendLocation = newValue!;
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
                      child: Text(location != null
                          ? 'Altitude: ${location.altitude.toString()}'
                          : 'Altitude: ')),
                  Checkbox(
                    value: sendAltitude,
                    onChanged: (newValue) {
                      // this should make sure the permissions are enabled/requested
                      // _handlePermission();
                      setState(() {
                        sendAltitude = newValue!;
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
                      child: Text(location != null
                          ? 'Bearing: ${location.heading.toString()}'
                          : 'Bearing: ')),
                  Checkbox(
                    value: sendBearing,
                    onChanged: (newValue) {
                      // this should make sure the permissions are enabled/requested
                      // _handlePermission();
                      setState(() {
                        sendBearing = newValue!;
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

  @override
  void dispose() {
    super.dispose();
    for (var subscription in _streamSubscriptions) {
      subscription.cancel();
    }
    _locationSubscription?.cancel();
  }

  @override
  void initState() {
    super.initState();

    location.enableBackgroundMode(enable: true);
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
        .add(magnetometerEvents.listen((MagnetometerEvent event) {
      if (sendMagnet && _sendingData) {
        Provider.of<DCD_client>(context, listen: false)
            .thing
            .updatePropertyByName(
                'Magnetic Field', [event.x, event.y, event.z]);
      }
      setState(() {
        _magnetometerValues = <double>[event.x, event.y, event.z];
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
    _locationSubscription =
        location.onLocationChanged.listen((LocationData currentLocation) {
      if (_sendingData) {
        if (sendLocation) {
          Provider.of<DCD_client>(context, listen: false)
              .thing
              .updatePropertyByName('location',
                  [currentLocation.latitude, currentLocation.longitude]);
        }
        if (sendAltitude) {
          Provider.of<DCD_client>(context, listen: false)
              .thing
              .updatePropertyByName('Altitude', [currentLocation.altitude]);
        }
        if (sendBearing) {
          Provider.of<DCD_client>(context, listen: false)
              .thing
              .updatePropertyByName('bearing', [currentLocation.heading]);
        }
      }

      _location = currentLocation;
    });
    // desired accuracy and the minimum distance change
    // (in meters) before updates are sent to the application - 1m in our case.
  }
}
