import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'opengl_scene.dart';

class TossMasterScene extends StatefulWidget {
  const TossMasterScene({super.key, required this.title});

  final String title;

  @override
  State<TossMasterScene> createState() => _TossMasterSceneState();
}

class _TossMasterSceneState extends State<TossMasterScene> {
  int width = -1;
  int height = -1;
  double fps = -1;
  String backend = "unknown";
  final vc = cv.VideoCapture.empty();
  final vw = cv.VideoWriter.empty();
  bool isStreaming = false;

  Uint8List? _wroteFrame;

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  void requestPermission() async {
    // Check if the platform is not web, as web has no permissions
    if (!kIsWeb) {
      // Request storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }

      // Request camera permission
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        await Permission.camera.request();
      }
    }
  }

  Future<void> startStreaming() async {
    while (isStreaming) {
      final (success, frame) = vc.read();
      if (success) {
        final (encoded, bytes) = cv.imencode(".png", frame);
        frame.dispose();
        if (encoded) {
          setState(() {
            _wroteFrame = bytes;
          });
        } else {
          debugPrint("Frame encoding failed.");
        }
      } else {
        debugPrint("Failed to read frame from camera.");
      }
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await vc.openIndexAsync(0);
                    setState(() {
                      width = vc.get(cv.CAP_PROP_FRAME_WIDTH).toInt();
                      height = vc.get(cv.CAP_PROP_FRAME_HEIGHT).toInt();
                      fps = vc.get(cv.CAP_PROP_FPS);
                      backend = vc.getBackendName();
                    });
                  },
                  child: const Text("Start Camera"),
                )
              ],
            ),
            Text(
                "width: $width, height: $height, fps: $fps, backend: $backend"),
            ElevatedButton(
              child: const Text("Start"),
              onPressed: () async {
                if (!isStreaming) {
                  setState(() {
                    isStreaming = true;
                  });
                  startStreaming();
                } else {
                  setState(() {
                    isStreaming = false;
                  });
                }
              },
            ),
            const OpenGLScene(),
          ],
        ),
      ),
    );
  }
}
