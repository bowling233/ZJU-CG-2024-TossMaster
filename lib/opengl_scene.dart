import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'package:flutter_gl/native-array/NativeArray.app.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';
import 'opengl_utils.dart';

class Throttler {
  Throttler({required this.milliSeconds});

  final int milliSeconds;

  int? lastActionTime;

  void run(VoidCallback action) {
    if (lastActionTime == null) {
      action();
      lastActionTime = DateTime.now().millisecondsSinceEpoch;
    } else {
      if (DateTime.now().millisecondsSinceEpoch - lastActionTime! >
          (milliSeconds)) {
        action();
        lastActionTime = DateTime.now().millisecondsSinceEpoch;
      }
    }
  }
}

class OpenGLScene extends StatefulWidget {
  const OpenGLScene({super.key});
  @override
  State<OpenGLScene> createState() => _OpenGLSceneState();
}

class _OpenGLSceneState extends State<OpenGLScene> with WidgetsBindingObserver {
  // ***********************
  // Camera Part
  // ***********************
  List<CameraDescription> cameras = [];
  CameraController? cameraController;
  late Throttler throttler; // Throttler to limit camera frame rate
  NativeUint8Array? cameraData; // 背景纹理数据

  // ***********************
  // Camera Part
  // ***********************

  // ***********************
  // OpenGL Part
  // ***********************
  late FlutterGlPlugin flutterGlPlugin;
  int? fboId;
  num dpr = 1.0;
  Size? screenSize;
  late double width;
  late double height;
  // 离屏渲染用
  dynamic sourceTexture;
  dynamic defaultFramebuffer;
  dynamic defaultFramebufferTexture;
  // 背景用
  dynamic backgroundProgram; // 背景着色器
  dynamic backgroundVao;
  dynamic backgroundVbo;
  dynamic backgroundTexture;
  // 场景用
  dynamic sceneProgram; // 模型着色器
  dynamic sceneVao;
  dynamic sceneVbo;

  int t = DateTime.now().millisecondsSinceEpoch;

  // ********************
  // OpenGL 部分
  // ********************
  // 背景
  prepareBackground() {
    final gl = flutterGlPlugin.gl;
    // 背景着色器
    String version = "300 es";
    if (!kIsWeb) {
      if (Platform.isMacOS || Platform.isWindows) {
        version = "150";
      }
    }
    var vs = """#version $version
    layout(location = 0) in vec3 position;
    layout(location = 1) in vec2 texCoord;
    out vec2 TexCoord;
    void main() {
        gl_Position = vec4(position, 1.0);
        TexCoord = texCoord;
    }
    """;
    var fs = """#version $version
    precision mediump float;
    in vec2 TexCoord;
    out vec4 color;
    uniform sampler2D backgroundTexture;
    void main() {
        color = texture(backgroundTexture, TexCoord);
    }
    """;
    backgroundProgram = initShaders(gl, vs, fs);
    if (backgroundProgram == null) {
      developer.log('Failed to intialize shaders.');
      return;
    }
    // 顶点数据
    // 四个顶点和每个顶点的纹理坐标
    var vertices = Float32Array.fromList([
      // Positions        // Texture Coords
      -1.0, 1.0, 0.0, 0.0, 1.0, // Top Left
      -1.0, -1.0, 0.0, 0.0, 0.0, // Bottom Left
      1.0, -1.0, 0.0, 1.0, 0.0, // Bottom Right
      1.0, 1.0, 0.0, 1.0, 1.0 // Top Right
    ]);
    // VAO、VBO
    backgroundVao = gl.createVertexArray();
    gl.bindVertexArray(backgroundVao);
    var backgroundVbo = gl.createBuffer();
    if (backgroundVbo == null) {
      developer.log('Failed to create the buffer object');
      return -1;
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, backgroundVbo);
    if (kIsWeb) {
      gl.bufferData(gl.ARRAY_BUFFER, vertices.length, vertices, gl.STATIC_DRAW);
    } else {
      gl.bufferData(
          gl.ARRAY_BUFFER, vertices.lengthInBytes, vertices, gl.STATIC_DRAW);
    }
    // 绑定位置（Position）属性
    gl.vertexAttribPointer(
        0, 3, gl.FLOAT, false, 5 * Float32List.bytesPerElement, 0);
    gl.enableVertexAttribArray(0);
    // 绑定纹理坐标（TexCoord）属性
    gl.vertexAttribPointer(1, 2, gl.FLOAT, false,
        5 * Float32List.bytesPerElement, 3 * Float32List.bytesPerElement);
    gl.enableVertexAttribArray(1);
    // 释放绑定
    gl.bindBuffer(gl.ARRAY_BUFFER, null);
    gl.bindVertexArray(null);
  }

  renderBackground() {
    final gl = flutterGlPlugin.gl;
    // 绑定背景着色器
    gl.useProgram(backgroundProgram);
    // 绑定 VAO
    gl.bindVertexArray(backgroundVao);
    // 绑定纹理
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, backgroundTexture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    // 传递纹理数据
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB,
        gl.UNSIGNED_BYTE, cameraData);
    // 设置纹理单元
    gl.uniform1i(
        gl.getUniformLocation(backgroundProgram, 'backgroundTexture'), 0);
    // 绘制
    gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
  }

  // 场景
  prepareScene() {
    final gl = flutterGlPlugin.gl;
    // 着色器
    String version = "300 es";
    if (!kIsWeb) {
      if (Platform.isMacOS || Platform.isWindows) {
        version = "150";
      }
    }
    var vs = """#version $version
#define attribute in
#define varying out
attribute vec3 a_Position;
// layout (location = 0) in vec3 a_Position;
void main() {
    gl_Position = vec4(a_Position, 1.0);
}
    """;

    var fs = """#version $version
out highp vec4 pc_fragColor;
#define gl_FragColor pc_fragColor

void main() {
  gl_FragColor = vec4(1.0, 1.0, 0.0, 1.0);
}
    """;
    sceneProgram = initShaders(gl, vs, fs);
    if (sceneProgram == null) {
      developer.log('Failed to intialize shaders.');
      return;
    }
    // 顶点数据
    var dim = 3;
    var vertices = Float32Array.fromList([
      -0.5, -0.5, 0, // Vertice #2
      0.5, -0.5, 0, // Vertice #3
      0, 0.5, 0, // Vertice #1
    ]);
    sceneVao = gl.createVertexArray();
    gl.bindVertexArray(sceneVao);
    var sceneVbo = gl.createBuffer();
    if (sceneVbo == null) {
      developer.log('Failed to create the buffer object');
      return -1;
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, sceneVbo);
    if (kIsWeb) {
      gl.bufferData(gl.ARRAY_BUFFER, vertices.length, vertices, gl.STATIC_DRAW);
    } else {
      gl.bufferData(
          gl.ARRAY_BUFFER, vertices.lengthInBytes, vertices, gl.STATIC_DRAW);
    }
    var aPosition = gl.getAttribLocation(sceneProgram, 'a_Position');
    if (aPosition < 0) {
      developer.log('Failed to get the storage location of a_Position');
      return -1;
    }
    gl.vertexAttribPointer(
        aPosition, dim, gl.FLOAT, false, Float32List.bytesPerElement * 3, 0);
    gl.enableVertexAttribArray(aPosition);
  }

  renderScene() {
    final gl = flutterGlPlugin.gl;
    gl.useProgram(sceneProgram);
    gl.bindVertexArray(sceneVao);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  render() {
    /**
     * OpenCV Part
     */
    // Read frame from camera
    // Identify the markers
    // get camera information

    /**
     * OpenGL Part
     */
    final gl = flutterGlPlugin.gl;
    int current = DateTime.now().millisecondsSinceEpoch;
    gl.viewport(0, 0, (width * dpr).toInt(), (height * dpr).toInt());
    num blue = sin((current - t) / 500);
    // Clear canvas
    gl.clearColor(1.0, 0.0, blue, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    // gl.clearColor(0.0, 0.0, 0.0, 0.0);
    // gl.clearDepth(1);
    // gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // draw background
    // if (cameraData != null) {
    //   renderBackground();
    // }

    // draw scene
    renderScene();

    gl.finish();

    if (!kIsWeb) {
      flutterGlPlugin.updateTexture(sourceTexture);
    }
  }

  // ********************
  // Init State
  // ********************
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (cameraController == null ||
        cameraController?.value.isInitialized == false) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCameraController();
    }
  }

  Future<void> _setupCameraController() async {
    WidgetsFlutterBinding.ensureInitialized();
    List<CameraDescription> cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      final cameraDescription = cameras
          .where(
            (element) => element.lensDirection == CameraLensDirection.back,
          )
          .first;
      // debug: print camera properties
      developer.log(
          "selected camera: ${cameraDescription.name} ${cameraDescription.lensDirection}");

      setState(() {
        cameraController = CameraController(
          cameraDescription,
          ResolutionPreset.medium,
          enableAudio: false,
          // 32-bit BGRA.
          imageFormatGroup: ImageFormatGroup.bgra8888,
        );
      });
      cameraController?.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      }).catchError(
        (Object e) {
          developer.log(e.toString());
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();

    // start camera
    requestPermission();
    _setupCameraController();

    throttler = Throttler(milliSeconds: 25);
  }

  void requestPermission() async {
    if (!kIsWeb) {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        await Permission.camera.request();
      }
    }
  }

  // ********************
  // Build (Prepare)
  // ********************

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    width = screenSize!.width;
    height = width;

    flutterGlPlugin = FlutterGlPlugin();

    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": width.toInt(),
      "height": height.toInt(),
      "dpr": dpr
    };

    await flutterGlPlugin.initialize(options: options);

    developer.log(" flutterGlPlugin: textureid: ${flutterGlPlugin.textureId} ");

    setState(() {});

    // web need wait dom ok!!!
    Future.delayed(const Duration(milliseconds: 100), () {
      setup();
    });
  }

  setup() async {
    // web no need use fbo
    if (!kIsWeb) {
      await flutterGlPlugin.prepareContext();

      setupDefaultFBO();
      sourceTexture = defaultFramebufferTexture;
    }

    setState(() {});

    prepareScene();

    animate();
  }

  initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mq = MediaQuery.of(context);

    screenSize = mq.size;
    dpr = mq.devicePixelRatio;

    developer.log(" screenSize: $screenSize dpr: $dpr ");

    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext context) {
        initSize(context);
        return SingleChildScrollView(child: _build(context));
      },
    );
  }

  Widget _build(BuildContext context) {
    if (cameraController == null ||
        cameraController?.value.isInitialized == false) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (cameraController?.value.isStreamingImages == false) {
      cameraController?.startImageStream((image) async {
        throttler.run(() async {
          // convert image to Image
          imglib.Image processedImage = convertCameraImage(image);
          int x = (processedImage.width - width.toInt()) ~/ 2;
          int y = (processedImage.height - height.toInt()) ~/ 2;
          processedImage = imglib.copyCrop(processedImage,
              x: x, y: y, width: width.toInt(), height: height.toInt());

          setState(() {
            cameraData = NativeUint8Array.from(processedImage.toUint8List());
          });

          // debug: print image and data properties
          developer.log(
              "[startImageStream] image: ${processedImage.width}x${processedImage.height} ${processedImage.format}");
          developer.log("[startImageStream] cameraData: ${cameraData!.length}");
        });
      });
    }

    return Column(
      children: [
        Container(
            width: width,
            height: width,
            color: Colors.black,
            child: Builder(builder: (BuildContext context) {
              if (kIsWeb) {
                return flutterGlPlugin.isInitialized
                    ? HtmlElementView(
                        viewType: flutterGlPlugin.textureId!.toString())
                    : Container();
              } else {
                return flutterGlPlugin.isInitialized
                    ? Texture(textureId: flutterGlPlugin.textureId!)
                    : Container();
              }
            })),
        //cameraData == null ? const Placeholder() : Image.memory(cameraData!),
      ],
    );
  }

  // 创建 FBO 用于离屏渲染
  setupDefaultFBO() {
    final gl = flutterGlPlugin.gl;
    int glWidth = (width * dpr).toInt();
    int glHeight = (height * dpr).toInt();

    developer.log("glWidth: $glWidth glHeight: $glHeight ");

    defaultFramebuffer = gl.createFramebuffer();
    defaultFramebufferTexture = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);

    gl.bindTexture(gl.TEXTURE_2D, defaultFramebufferTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, glWidth, glHeight, 0, gl.RGBA,
        gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    gl.bindFramebuffer(gl.FRAMEBUFFER, defaultFramebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D,
        defaultFramebufferTexture, 0);
  }

  // ********************
  // Animate
  // ********************

  animate() {
    render();

    Future.delayed(const Duration(milliseconds: 33), () {
      animate();
    });
  }
}
