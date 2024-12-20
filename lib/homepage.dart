import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:gal/gal.dart';
import 'dart:developer' as developer;
import 'opengl_scene.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: const OpenGLScene(),
    );
  }

  /*
  Widget _buildUI() {
    return SafeArea(
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const OpenGLScene(),
            IconButton(
              onPressed: () async {
                XFile picture = await cameraController!.takePicture();
                Gal.putImage(
                  picture.path,
                );
              },
              iconSize: 100,
              icon: const Icon(
                Icons.camera,
                color: Colors.red,
              ),
            )
          ],
        ),
      ),
    );
  }
  */
}
