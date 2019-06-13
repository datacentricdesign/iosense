import 'dart:async';  // async support
import 'dart:convert';  // json en/decoder

import 'package:flutter/material.dart';
import 'package:sensors/sensors.dart'; // flutter cross-platform sensor suite
import 'package:flutter_appauth/flutter_appauth.dart'; // AppAuth in flutter
import 'package:http/http.dart' as http;  //flutter http library

import 'dcd.dart' show DCD_client; // DCD(data centric design) definitions

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(), // dark theme applied
      home: MyHomePage(title: "Sensor Box"),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title and appauth object) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  bool _running_sensors_changed = false, streaming_to_hub = false;

  final Set<String> _running_sensors = Set<String>();


  // accelerometer forces along x, y and z axes , in m/s^2
  List<double> _user_accel_values; // save accel values without gravity
  //  Rate of rotation around x, y, z axes, in rad/s.
  List<double> _gyro_values; // saves rotation values, in radians


  // stores list of subscriptions to sensor event streams (async data sources)
  List<StreamSubscription<dynamic>> _stream_subscriptions =
  <StreamSubscription<dynamic>>[];

  // creating our client object
  DCD_client client = DCD_client();

  // app authentication object
  FlutterAppAuth appAuth = FlutterAppAuth();


  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // here we will update our values, before updating the UI
    // note that conditional member access operator is used (?.)
    // gyro values
    final List<String> gyroscope =
    _gyro_values?.map((double v) => v.toStringAsFixed(1))?.toList();
    // accel values
    final List<String> user_accelerometer = _user_accel_values
        ?.map((double v) => v.toStringAsFixed(1))
        ?.toList();


    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
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
            CheckboxListTile(
              title: Text("Accelerometer"),
              value: _running_sensors.contains("Accel"),
              onChanged: (bool new_value) {
                setState(() {
                  new_value ? _running_sensors.add("Accel") : _running_sensors
                      .remove("Accel");

                  _running_sensors_changed = true; //set to stream has changed
                  streaming_to_hub =false; // stop streaming
                });
              },

            ),
            Visibility( // widget does not take any visible space when invisible
              child: Text("{x,y,z} m/s^2 = $user_accelerometer"),
              visible: _running_sensors.contains("Accel"),
            ),

            CheckboxListTile(
              title: Text("Gyroscope"),
              value: _running_sensors.contains("Gyro"),
              onChanged: (bool new_value) {
                setState(() {
                  new_value ? _running_sensors.add("Gyro") : _running_sensors
                      .remove("Gyro");

                  _running_sensors_changed = true; //set to stream has changed
                  streaming_to_hub =false;
                });
              },
            ),
            Visibility( // widget does not take any visible space when invisible
              child: Text("{x,y,z} rad/s  m/s^2.$gyroscope"),
              visible: _running_sensors.contains("Gyro"),
            ),
            Visibility( //if there are any sensors running
              child: RaisedButton(
                onPressed: ()  async {
                  setState(() {
                    _running_sensors_changed = false; // from this point we're streaming
                    streaming_to_hub = true;
                  });

                  await stream_to_hub();
                  
                  var response = await interact_hub_http();


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
    for (StreamSubscription<dynamic> subscription in _stream_subscriptions) {
      subscription.cancel();
    }
  }

  // registering our sensor stream subscriptions
  // called when stateful widget is inserted in widget tree.
  @override
  void initState() {
    super.initState(); // must be included

    // start subscription once, update values for each event time
    _stream_subscriptions.add(
        gyroscopeEvents.listen((GyroscopeEvent event) {
          setState(() {
            _gyro_values = <double>[event.x, event.y, event.z];
          });
        })
    );

    _stream_subscriptions.add(
        userAccelerometerEvents.listen(
                (UserAccelerometerEvent event) {
              setState(() {
                _user_accel_values = <double>[event.x, event.y, event.z];
              });
            })
    );
  }

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

    if (result != null) {
      setState(() {
        // save the code verifier as it must be used when exchanging the token
        client.access_token = result.accessToken;
        client.create_thing("myphonedevice", client.access_token)
        streaming_to_hub = true;
        
      });
    }
  }

  Future<http.Response> interact_hub_http() async {
    var http_response = await http.get('https://dwd.tudelft.nl/api/things',
        headers: {'Authorization': 'Bearer ${client.access_token}'});

    var aba = jsonDecode(http_response.body);
    var thing = aba["things"];
    var lala = thing[0]["id"];

    return(http_response);
  }

}

