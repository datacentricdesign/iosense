import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:provider/provider.dart';
import '../dcd.dart' show DCD_client; // DCD(data centric design) definitions

// TODO: switch cameras
// TODO: simplify code
// TODO: reduce random functions
// TODO: make it clear when the video is going to be recorded
// TODO: make it clear where video is saved
List<CameraDescription>? cameras;

class CameraApp extends StatefulWidget {
  final _CameraAppState cameraPage = _CameraAppState();

  @override
  State<StatefulWidget> createState() => cameraPage;
}

class _CameraAppState extends State<CameraApp>
    with AutomaticKeepAliveClientMixin<CameraApp> {
  @override
  bool get wantKeepAlive => true;
  late CameraController controller;
  bool _sendingVideo = false;
  bool _wasSendingVideo = false;
  bool _sendingData = false;
  bool _wasSendingData = false;

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras![1], ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void toggleSendVideo() {
    /// toggles the sendVideo bit and checks how to address the start video
    //set the appropriate UI bit
    setState(() {
      _sendingVideo = !_sendingVideo;
    });
    checkRecording();
  }

  void checkRecording() {
    /// slightly convoluted function to check if we are recording video and are supposed to start or stop
    /// basically, if we were recording, but now we're not -> stop video
    /// if we are not recording, but we need to start -> start video
    ///

    if ((_sendingData != _wasSendingData) ||
        (_sendingVideo != _wasSendingVideo)) {
      // there's been a change in if we are sending data and/or should send video
      setState(() {
        _wasSendingData = _sendingData;
        _wasSendingVideo = _sendingVideo;
      });

      if (_sendingData && _sendingVideo) {
        // we are sending data, and we are sending video, so send video
        // were not recording, but should be
        onVideoRecordButtonPressed();
        return;
      } else {
        // were recording, but should not be
        onStopButtonPressed();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!controller.value.isInitialized) {
      return Container(
        child: Text("camera error!"),
      );
    }

    _sendingData = Provider.of<DCD_client>(context).sendingData;
    checkRecording();
    return Scaffold(
      //TODO: add a button to start recording video
      //TODO: add a button to mute/unmute audio
      //TODO: add a button to switch cameras

      body: Container(child: CameraPreview(controller)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: 200.0,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              FloatingActionButton(
                child: const Icon(Icons.switch_camera),
                onPressed: () {
                  switchCameras();
                },
              ),
              FloatingActionButton(
                backgroundColor: _sendingVideo ? Colors.red : Colors.blue,
                child: _sendingVideo
                    ? const Icon(Icons.videocam)
                    : const Icon(Icons.videocam_off),
                onPressed: () {
                  toggleSendVideo();
                },
              ),
              FloatingActionButton(
                child: const Icon(Icons.mic_off),
                onPressed: () {},
              )
            ]),
      ),
    );
  }

  Future<void> switchCameras() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return;
    }

    if (cameraController.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      showInSnackBar('Cannot switch while streaming (yet)');
      return;
    }

    showInSnackBar("switching cameras (soon)");
  }

  void showInSnackBar(message) {
    //helper function to show a snackbar
    final snackBar = SnackBar(
      content: Text(message),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((_) {
      if (mounted) setState(() {});
    });
  }

  void onStopButtonPressed() {
    stopVideoRecording().then((file) {
      if (mounted) setState(() {});
      if (file != null) {
        GallerySaver.saveVideo(file.path);
        showInSnackBar('Video recorded to the \'Movies\' folder');
      }
    });
  }

  //TODO: record video locally
  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return;
    }

    if (cameraController.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return;
    }

    try {
      await cameraController.startVideoRecording();
    } on CameraException catch (e) {
      print(e);
      return;
    }
  }

  Future<XFile?> stopVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      return cameraController.stopVideoRecording();
    } on CameraException catch (e) {
      print(e);
      return null;
    }
  }
}
