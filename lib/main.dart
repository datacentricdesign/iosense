import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors/sensors.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;


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

  bool _runningSensorsChanged = false, streamingToHub = false;

  final Set<String> _runningSensors = Set<String>();


  // accel forces along x, y and z axes , in m/s^2
  List<double> _userAccelerometerValues; // save accel values without gravity
  //  Rate of rotation around x, y, z axes, in rad/s.
  List<double> _gyroscopeValues; // saves rotation values, in radians


  // stores list of subscriptions to sensor event streams (async data sources)
  List<StreamSubscription<dynamic>> _streamSubscriptions =
  <StreamSubscription<dynamic>>[];

  // creating our client object
  DCDClient client = DCDClient();

  // app authentication object
  FlutterAppAuth appAuth = FlutterAppAuth();


  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // here we will update our values, before updating the UI
    // note that conditional member access operator is used (?.)
    // gyro values
    final List<String> gyroscope =
    _gyroscopeValues?.map((double v) => v.toStringAsFixed(1))?.toList();
    // accel values
    final List<String> userAccelerometer = _userAccelerometerValues
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
              value: _runningSensors.contains("Accel"),
              onChanged: (bool new_value) {
                setState(() {
                  new_value ? _runningSensors.add("Accel") : _runningSensors
                      .remove("Accel");

                  _runningSensorsChanged = true;
                });
              },

            ),
            Visibility( // widget does not take any visible space when invisible
              child: Text("{x,y,z} m/s^2 = $userAccelerometer"),
              visible: _runningSensors.contains("Accel"),
            ),

            CheckboxListTile(
              title: Text("Gyroscope"),
              value: _runningSensors.contains("Gyro"),
              onChanged: (bool new_value) {
                setState(() {
                  new_value ? _runningSensors.add("Gyro") : _runningSensors
                      .remove("Gyro");

                  _runningSensorsChanged = true;
                });
              },
            ),
            Visibility( // widget does not take any visible space when invisible
              child: Text("{x,y,z} rad/s  m/s^2.$gyroscope"),
              visible: _runningSensors.contains("Gyro"),
            ),
            Visibility( //if there are any sensors running
              child: RaisedButton(
                onPressed: ()  {
                  setState(() {
                    _runningSensorsChanged = false; // from this point we're streaming
                    streamingToHub = true;
                  });

                  stream_to_hub();

                },
                child: Text('Stream data to Hub'),
              ),
              visible: _runningSensors.isNotEmpty && _runningSensorsChanged,

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
    for (StreamSubscription<dynamic> subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  // registering our sensor stream subscriptions
  // called when stateful widget is inserted in widget tree.
  @override
  void initState() {
    super.initState(); // must be included

    // start subscription once, update values for each event time
    _streamSubscriptions.add(
        gyroscopeEvents.listen((GyroscopeEvent event) {
          setState(() {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
          });
        })
    );

    _streamSubscriptions.add(
        userAccelerometerEvents.listen(
                (UserAccelerometerEvent event) {
              setState(() {
                _userAccelerometerValues = <double>[event.x, event.y, event.z];
              });
            })
    );
  }

  Future stream_to_hub() async
  {
    var result = await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          client.id,
          client.redirectUrl.toString(),
          clientSecret: client.secret,
          serviceConfiguration: AuthorizationServiceConfiguration(
              client.authorizationEndpoint.toString(),
              client.tokenEndpoint.toString()
          ),
        )

    );

    if (result != null) {
      setState(() {
        // save the code verifier as it must be used when exchanging the token
        client.accessToken = result.accessToken;
      });
    }
  }

  Future interact_hub_http(TokenResponse response) async {
    var httpResponse = await http.get('string',
        headers: {'Authorization': 'Bearer ${client.accessToken}'});

  }

}

// client of DCD,
// used to receive the token and connect to the hub.
class DCDClient
{
    final authorizationEndpoint =
    Uri.parse("https://dwd.tudelft.nl/oauth2/auth");
    final tokenEndpoint =
    Uri.parse("https://dwd.tudelft.nl/oauth2/token");
    final id = "dcd-hub-android";
    final secret = "BZ2y0LDdoGxGqSHBS_0-Dm6wyz";
  // This is a URL on your application's server. The authorization server
  // will redirect the resource owner here once they've authorized the
  // client. The redirection will include the authorization code in the
  // query parameters.
    final redirectUrl = Uri.parse("nl.tudelft.ide.dcd-hub-android:/oauth2redirect");
    String accessToken;

}

class DCD_broker
{
  bool find_or_create_thing()
  {
    return(true);
  }

  bool find_or_create_property()
  {
    return(true);
  }

  bool upload_values()
  {
    
  }


}