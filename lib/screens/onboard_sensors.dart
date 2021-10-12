import 'dart:async'; // async support
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart'; // flutter cross-platform sensor suite
import 'package:location/location.dart';
import '../dcd.dart' show DCD_client; // DCD(data centric design) definitions

class SensorPage extends StatefulWidget {
  const SensorPage({Key? key}) : super(key: key);

  @override
  _SensorPageState createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage>
    with AutomaticKeepAliveClientMixin<SensorPage> {
  @override
  bool get wantKeepAlive => true;

  List<double>? _userAccelerometerValues;
  List<double>? _gyroscopeValues;
  List<double>? _magnetometerValues;
  final Location location = Location();
  late PermissionStatus _permissionGranted;
  late bool _serviceEnabled;

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

  @override
  Widget build(BuildContext context) {
    _sendingData = Provider.of<DCD_client>(context).sendingData;
    final gyroscope =
        _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final userAccelerometer = _userAccelerometerValues
        ?.map((double v) => v.toStringAsFixed(1))
        .toList();
    final magnetometer =
        _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final location = _location;

    return Container(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                Text(
                  '${Provider.of<DCD_client>(context).thing.id}',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                )
              ],
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text(
                'Sensor:',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const Text(
                'Send to Bucket',
                overflow: TextOverflow.ellipsis,
              ),
            ]),
            const Divider(),
            Row(
              children: [
                Text(
                  'IMU',
                  style: Theme.of(context).textTheme.caption,
                )
              ],
            ),
            Row(
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
            Row(
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
            /////// this removes missbehaving magnetometer from UI
            ///TODO: figure out if the sample rate can be changed
            ///TODO:
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: <Widget>[
            //     Text('Magnetometer: $magnetometer'),
            //     Checkbox(
            //       value: sendMagnet,
            //       onChanged: (newValue) {
            //         setState(() {
            //           sendMagnet = newValue!;
            //         });
            //       },
            //     ),
            //   ],
            // ),
            const Divider(),
            Row(
              children: [
                Text(
                  'GPS',
                  style: Theme.of(context).textTheme.caption,
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                    child: Text(location != null
                        ? 'Location: ${location.latitude.toString()}, ${location.longitude.toString()}'
                        : 'Location: ')),
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
            Row(
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
            Row(
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
            const Divider(),
            Text("sending data is $_sendingData"),
            const Divider(),
            Row(
              children: [
                Text(
                  '1. press the ! on the top right to log in',
                  style: Theme.of(context).textTheme.caption,
                )
              ],
            ),
            Row(
              children: [
                Text(
                  '2. select the sensors to stream',
                  style: Theme.of(context).textTheme.caption,
                )
              ],
            ),
            Row(
              children: [
                Text(
                  '3. press the play to start streaming',
                  style: Theme.of(context).textTheme.caption,
                )
              ],
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

  Future<void> checkLocationPermissions() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();

    location.enableBackgroundMode(enable: true);
    checkLocationPermissions();
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
                'Magnetic_Field', [event.x, event.y, event.z]);
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
