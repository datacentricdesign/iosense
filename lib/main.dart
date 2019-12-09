import 'dart:async';  // async support
import 'dart:convert';  // json en/decoder

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors/sensors.dart'; // flutter cross-platform sensor suite
import 'package:flutter_appauth/flutter_appauth.dart'; // AppAuth in flutter
import 'package:http/http.dart' as http;  //flutter http library
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // package for geolocation
import 'package:camera/camera.dart'; // package for camera
import 'package:path/path.dart' show join; // package for path manipulation
import 'package:path_provider/path_provider.dart'; // package for path finding
import 'package:mqtt_client/mqtt_client.dart'; // package for MQTT connection

import 'dcd.dart' show DCD_client, Thing; // DCD(data centric design) definitions

// async main to call our main app state, after retrieving camera
Future<void> main() async {
  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  runApp(MyApp(active_camera: firstCamera));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  // camera to be used
  final CameraDescription active_camera;

  // constructor with default attribution to field
  MyApp({this.active_camera});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(), // dark theme applied
      home: MyHomePage(title: "DCD Hub", camera: active_camera,),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title, this.camera}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title and appauth object) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  // holds camera descrition
  final CameraDescription camera;
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  // camera controller, establishes a connection to the device’s camera
  CameraController _controller;
  // stores the Future returned from CameraController.initialize().
  Future<void> _initializeControllerFuture;

  // state variables to help with UI rendering and sensor updates
  bool _running_sensors_changed = false, streaming_to_hub = false;

  // set holding currently running sensors
  final Set<String> _running_sensors = Set<String>();


  // accelerometer forces along x, y and z axes , in m/s^2
  List<double> _user_accel_values; // save accel values without gravity
  //  Rate of rotation around x, y, z axes, in rad/s.
  List<double> _gyro_values; // saves rotation values, in radians

  // saves location data, 5D:
  // latitude in degrees normalized to the interval [-90.0,+90.0]
  // longitude in degrees normalized to the interval [-90.0,+90.0]
  // altitude in meters
  // speed at which the device is traveling in m/s over ground
  // timestamp time at which event was received from device
  List<dynamic> _loc_values;


  // stores list of subscriptions to sensor event streams (async data sources)
  List<StreamSubscription<dynamic>> _stream_subscriptions =
  <StreamSubscription<dynamic>>[];

  // creating our client object
  DCD_client client = DCD_client();

  // app authentication object
  FlutterAppAuth appAuth = FlutterAppAuth();

  // shared preferences file to save thing id's in hub if already created
  SharedPreferences thing_prefs;


  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // here we will update our values, before updating the UI
    // note that conditional member access operator is used (?.)
    // gyro values
    final List<String> gyroscope =
    _gyro_values?.map((double v) => v.toStringAsFixed(3))?.toList();
    // accel values
    final List<String> user_accelerometer = _user_accel_values
        ?.map((double v) => v.toStringAsFixed(3))
        ?.toList();

    // if we're streaming to hub, update the property values in the hub
    if(streaming_to_hub) update_properties_hub();

    if(_loc_values == null) {
      _loc_values = [ 0, 0, 0, 0, 0];
    }



    // UI building
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        // in case we have recording, adding a record button
        leading:
          Visibility(
            // doing this so I can get largest size possible for icon
            child:  LayoutBuilder(builder: (context, constraint) {
                      return Icon(Icons.adjust,size: constraint.biggest.height *.85, color: Colors.red);
                   }),
            visible: streaming_to_hub,
          ),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[

            // Accelerometer

            CheckboxListTile(
              title: Text("Accelerometer"),
              value: _running_sensors.contains("Accel"),
              onChanged: (bool new_value) {
                _running_sensors_changed = true; //set to stream has changed
                streaming_to_hub =false; // stop streaming

                // updating our state since running sensors changes UI
                setState(() {
                  new_value ? _running_sensors.add("Accel") : _running_sensors
                      .remove("Accel");
                });
              },

            ),
            Visibility( // widget does not take any visible space when invisible
              child: Text("[x,y,z] (m/s^2) = $user_accelerometer"),
                          //textAlign: TextAlign.start),
              visible: _running_sensors.contains("Accel"),
            ),

            // Gyroscope

            CheckboxListTile(
              title: Text("Gyroscope"),
              value: _running_sensors.contains("Gyro"),
              onChanged: (bool new_value) {
                _running_sensors_changed = true; //set to stream has changed
                streaming_to_hub =false;

                // updating our state since running sensors changes UI
                setState(() {
                  new_value ? _running_sensors.add("Gyro") : _running_sensors
                      .remove("Gyro");
                });
              },
            ),
            Visibility( // widget does not take any visible space when invisible
              child: Text("[x,y,z] (rad/s) = $gyroscope"),
                          //textAlign: TextAlign.start),
              visible: _running_sensors.contains("Gyro"),
            ),

            // Location tracking

            CheckboxListTile(
              title: Text("Location"),
              value: _running_sensors.contains("Location"),
              onChanged: (bool new_value) {
                _running_sensors_changed = true; //set to stream has changed
                streaming_to_hub =false; // stop streaming

                // updating our state since running sensors changes UI
                setState(() {
                  new_value ? _running_sensors.add("Location") : _running_sensors
                      .remove("Location");
                });
              },

            ),
            Visibility( // widget does not take any visible space when invisible
              child: Padding (
                        padding:  EdgeInsets.symmetric(horizontal: 20.0),
                        child:  Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            //mainAxisSize: ,
                            children: <Widget>[
                              Text("Latitude ([-90.0,+90.0]°) = ${_loc_values[0]??" " }"),
                              Text("Longitude ([-90.0,+90.0]°) = ${_loc_values[1]??" "}"),
                              Text("Altitude (m) = ${_loc_values[2]??" "}"),
                              Text("Speed over ground (m/s) = ${_loc_values[3]??" "}"),
                              Text("Timestamp (GMT) = ${_loc_values[4]?.toString()}"),
                            ],
                          ),
                     ),
              visible: _running_sensors.contains("Location"),
            ),
            // Camera feed
            CheckboxListTile(
              title: Text("Camera"),
              value: _running_sensors.contains("Camera"),
              onChanged: (bool new_value) {
                _running_sensors_changed = true; //set to stream has changed
                streaming_to_hub =false; // stop streaming

                // updating our state since running sensors changes UI
                setState(() {
                  new_value ? _running_sensors.add("Camera") : _running_sensors
                      .remove("Camera");
                });
              },

            ),
            Visibility( // widget does not take any visible space when invisible
              // Wait until the controller is initialized before displaying the
              // camera preview. Use a FutureBuilder to display a loading spinner
              // until the controller has finished initializing.
              child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // If the Future is complete, display the preview.
                  return(
                    Flexible(child: Padding(padding: EdgeInsets.symmetric(vertical: 5.0),
                                            child: AspectRatio(
                                              aspectRatio: _controller.value.aspectRatio,
                                              child: CameraPreview(_controller)
                                            )
                                    )
                    )
                  );
                } else {
                  // Otherwise, display a loading indicator.
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
              visible: _running_sensors.contains("Camera"),
            ),
            // Stream to hub button
            Visibility( //if there are any sensors running
              child: RaisedButton(
                onPressed: () async {
                  // do not go forwards until streaming has happened
                  await stream_to_hub();

                  setState(() {
                    _running_sensors_changed = false; // from this point we're streaming
                    streaming_to_hub = true;
                  });

                 // var response = await interact_hub_http();


                },
                child: Text('Stream data to Hub'),
              ),
              visible: _running_sensors.isNotEmpty && _running_sensors_changed,

            ),

          ],
        ),
      ),

    );
  }

  // unregistering our sensor stream subscriptions
  @override
  void dispose() {
    super.dispose();

    // unsubscribe from open streams
    for (StreamSubscription<dynamic> subscription in _stream_subscriptions) {
      subscription.cancel();
    }

    // Dispose of the camera controller when the widget is disposed.
    _controller.dispose();
  }

  // registering our sensor stream subscriptions
  // called when stateful widget is inserted in widget tree.
  @override
  void initState()  {
    super.initState(); // must be included
    // start subscription once, update values for each event time

    // Gyroscope subscription
    _stream_subscriptions.add(
        gyroscopeEvents.listen((GyroscopeEvent event) {
          setState(() {
            _gyro_values = <double>[event.x, event.y, event.z];
          });
        })
    );

    // Accelerometer subscription
    _stream_subscriptions.add(
        userAccelerometerEvents.listen(
                (UserAccelerometerEvent event) {
              setState(() {
                _user_accel_values = <double>[event.x, event.y, event.z];
              });
            })
    );

    // Location subscription
    var geolocator = Geolocator();
    // desired accuracy and the minimum distance change
    // (in meters) before updates are sent to the application - 1m in our case.
    var location_options = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 1);
    _stream_subscriptions.add(
        geolocator.getPositionStream(location_options).listen(
            (Position event) {
              setState(() {
                _loc_values = <dynamic>[event.latitude,
                                       event.longitude,
                                       event.altitude,
                                       event.speed,
                                       event.timestamp];
              });

        })
    );

    // camera controller to display the current output from the camera,
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();

  }



  // Stream to hub function, connects to it and sends data
  Future stream_to_hub() async
  {
    var result = await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
            client.id,
            client.redirect_url.toString(),
            discoveryUrl: "https://dwd.tudelft.nl/.well-known/openid-configuration"
          //clientSecret: client.secret,
          //serviceConfiguration: AuthorizationServiceConfiguration(
          //    client.authorization_endpoint.toString(),
          //     client.token_endpoint.toString()
          //),
        )

    );

    if (result != null)  {
      // save the code verifier as it must be used when exchanging the token
      client.access_token =  result.accessToken;
      streaming_to_hub = true;

      // two following functions depend on each other, so sequential
      // processing is in order for correct functionality

      //await remove_thing_from_disk();
      // get shared preferences object
      thing_prefs = await SharedPreferences.getInstance();
      // delete everything in hub
      //await remove_thing_from_disk();
      //await client.delete_things_hub(["myphonedevice-5911", "myphonedevice-608e"]);

      final json_str = await thing_prefs.getString('cached_thing') ?? '';

      if(json_str.isEmpty) {
          await client.create_thing("myphonedevice", client.access_token);
          await create_properties_hub();
          await save_thing_to_disk();


      } else {
        client.thing = Thing.from_json(jsonDecode(json_str));
        // debugPrint(client.thing.toString());
      }

    }
  }

  // Test function, sees if hub is interactive
  // can be used to check response type
  // breakpoints can be used in variables to check response struct
  // and link can be changed to change test hub directory
  Future<http.Response> interact_hub_http() async
  {
    var http_response = await http.get('https://dwd.tudelft.nl/api/things',
                                        headers: {'Authorization':
                                                  'Bearer ${client.access_token}'});

    var aba = jsonDecode(http_response.body);
    var thing = aba["things"];
    var lala = thing[0]["id"];

    return(http_response);
  }


  // Creates properties in hub that thing uses
  void create_properties_hub() async
  {
    if( client.access_token == null) throw Exception("Invalid client access token");

      // Sequential creation of properties
      await client.thing.create_property("GYROSCOPE", client.access_token);
      await client.thing.create_property("ACCELEROMETER", client.access_token);
      // 5D location property vector
      await client.thing.create_property("FOUR_DIMENSIONS", client.access_token);
      // after thing and client are created, save them to disk
      await save_thing_to_disk();
  }

  // Updates the properties that are selected in the hub
  // current implementation updates all sensors at the rate of the fastest
  void update_properties_hub()
  {
    var sensor_list_size = 3;  // holds amount of sensors currently implemented
    // do not do anything until client is established
    if(client.thing == null) return;

    // do not do anything unless it is a running sensor and is established in hub
    if( _running_sensors.contains(("Gyro")) &&
        client.thing.properties.length == sensor_list_size) {
            client.thing.update_property_http(client.thing.properties[0],
                                         _gyro_values,
                                         client.access_token);
    }

    if( _running_sensors.contains(("Accel")) &&
        client.thing.properties.length == sensor_list_size) {
             client.thing.update_property_http(client.thing.properties[1],
                                          _user_accel_values,
                                          client.access_token);
    }

    if( _running_sensors.contains(("Location")) &&
        client.thing.properties.length == sensor_list_size) {

            if (listEquals<dynamic>(_loc_values, [0,0,0,0,0])) {
              return;
            }

            client.thing.update_property_http(client.thing.properties[2],
                                         _loc_values,
                                         client.access_token);
    }


    interact_hub_http();
  }

  // saves connected client thing ids to disk using shared preferences
  void save_thing_to_disk()
  {
    // Get Json string encoding thing
   var json_str =  jsonEncode(client.thing.to_json());
   thing_prefs.setString("cached_thing", json_str);
   //debugPrint(json_str);
  }

  // remove shared preferences for file
  void remove_thing_from_disk()
  {
    thing_prefs.remove("cached_thing");
  }



}

