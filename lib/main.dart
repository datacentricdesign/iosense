import 'dart:async'; // async support
// json en/decoder

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dcd.dart' show DCD_client; // DCD(data centric design) definitions
import './screens/onboard_sensors.dart';
import './screens/camera_page.dart';
import 'package:camera/camera.dart';

// async main to call our main app state, after retrieving camera
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of the available cameras on the device.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print(e.code);
    print(e.description);
  }
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
  bool _sendingData = false;

  void toggleSendData() {
    // keeps track of the sending data UI bit
    _sendingData = !_sendingData;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 2,
        child: Scaffold(
            appBar: AppBar(
              title: const Text('ioSense'),
              actions: <Widget>[
                Padding(
                    padding: EdgeInsets.only(right: 20.0),
                    child: GestureDetector(
                      onTap: () {
                        Provider.of<DCD_client>(context, listen: false)
                            .toggleSendingData();
                      },
                      child: Icon(Provider.of<DCD_client>(context).sendingData
                          ? Icons.pause
                          : Icons.play_arrow),
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
            body: TabBarView(
              children: [SensorPage(), CameraApp()],
            )));
  }
}
