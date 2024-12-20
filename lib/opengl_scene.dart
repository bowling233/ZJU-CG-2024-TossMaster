import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'package:flutter_gl/openGL/opengl/opengl_es_bindings/opengl_es_bindings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'dart:developer' as developer;
import 'package:image/image.dart' as img;

class OpenGLScene extends StatefulWidget {
  const OpenGLScene({super.key});
  @override
  State<OpenGLScene> createState() => _OpenGLSceneState();
}

class _OpenGLSceneState extends State<OpenGLScene> {
  late FlutterGlPlugin flutterGlPlugin;

  int? fboId;
  num dpr = 1.0;
  late double width;
  late double height;

  Size? screenSize;

  dynamic glProgram;
  dynamic _vao;

  dynamic sourceTexture;

  dynamic defaultFramebuffer;
  dynamic defaultFramebufferTexture;

  int n = 0;

  int t = DateTime.now().millisecondsSinceEpoch;

  // OpenCV Part
  // Camera
  int vcWidth = -1;
  int vcWeight = -1;
  double vcFps = -1;
  String vcBackend = "unknown";
  double vcRotation = -1;
  final vc = cv.VideoCapture.empty();
  // Camera Frame
  dynamic vcTexture;

  // ********************
  // Init State
  // ********************
  @override
  void initState() {
    super.initState();

    // setup OpenCV VideoCapture
    requestPermission();
    // vc.openIndex(0);
    // // OpenCV supported properties on android see https://github.com/rainyl/opencv_dart/issues/159#issuecomment-2238065384
    // vc.set(cv.CAP_PROP_FRAME_WIDTH, 1024.0);
    // vc.set(cv.CAP_PROP_FRAME_HEIGHT, 768.0);
    // vcWidth = vc.get(cv.CAP_PROP_FRAME_WIDTH).toInt();
    // vcWeight = vc.get(cv.CAP_PROP_FRAME_HEIGHT).toInt();
    // vcFps = vc.get(cv.CAP_PROP_FPS);
    // vcBackend = vc.getBackendName();
    // vcRotation = vc.get(cv.CAP_PROP_ORIENTATION_META);
    // // debug: show camera information
    // developer.log("vcWidth: $vcWidth vcWeight: $vcWeight vcFps: $vcFps vcBackend: $vcBackend");
    // developer.log("vcRotation: $vcRotation");
    // developer.log(" init state..... ");
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

    prepare();

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
      ],
    );
  }

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

  prepare() {
    final gl = flutterGlPlugin.gl;

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

    if (!initShaders(gl, vs, fs)) {
      developer.log('Failed to intialize shaders.');
      return;
    }

    // Write the positions of vertices to a vertex shader
    n = initVertexBuffers(gl);
    if (n < 0) {
      developer.log('Failed to set the positions of the vertices');
      return;
    }

    // init camera texture
    vcTexture = gl.createTexture();
  }

  initVertexBuffers(gl) {
    // Vertices
    var dim = 3;
    var vertices = Float32Array.fromList([
      -0.5, -0.5, 0, // Vertice #2
      0.5, -0.5, 0, // Vertice #3
      0, 0.5, 0, // Vertice #1
    ]);

    _vao = gl.createVertexArray();
    gl.bindVertexArray(_vao);

    // Create a buffer object
    var vertexBuffer = gl.createBuffer();
    if (vertexBuffer == null) {
      developer.log('Failed to create the buffer object');
      return -1;
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);

    if (kIsWeb) {
      gl.bufferData(gl.ARRAY_BUFFER, vertices.length, vertices, gl.STATIC_DRAW);
    } else {
      gl.bufferData(
          gl.ARRAY_BUFFER, vertices.lengthInBytes, vertices, gl.STATIC_DRAW);
    }

    // Assign the vertices in buffer object to a_Position variable
    var aPosition = gl.getAttribLocation(glProgram, 'a_Position');
    if (aPosition < 0) {
      developer.log('Failed to get the storage location of a_Position');
      return -1;
    }

    gl.vertexAttribPointer(
        aPosition, dim, gl.FLOAT, false, Float32List.bytesPerElement * 3, 0);
    gl.enableVertexAttribArray(aPosition);

    // Return number of vertices
    return vertices.length ~/ dim;
  }

  initShaders(gl, vsSource, fsSource) {
    // Compile shaders
    var vertexShader = makeShader(gl, vsSource, gl.VERTEX_SHADER);
    var fragmentShader = makeShader(gl, fsSource, gl.FRAGMENT_SHADER);

    // Create program
    glProgram = gl.createProgram();

    // Attach and link shaders to the program
    gl.attachShader(glProgram, vertexShader);
    gl.attachShader(glProgram, fragmentShader);
    gl.linkProgram(glProgram);
    var res = gl.getProgramParameter(glProgram, gl.LINK_STATUS);
    developer.log(" initShaders LINK_STATUS _res: $res ");
    if (res == false || res == 0) {
      developer.log("Unable to initialize the shader program");
      return false;
    }

    // Use program
    gl.useProgram(glProgram);

    return true;
  }

  makeShader(gl, src, type) {
    var shader = gl.createShader(type);
    gl.shaderSource(shader, src);
    gl.compileShader(shader);
    var res = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
    if (res == 0 || res == false) {
      developer.log("Error compiling shader: ${gl.getShaderInfoLog(shader)}");
      return;
    }
    return shader;
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

  renderBackground(cv.Mat frame) {
    final gl = flutterGlPlugin.gl;
    gl.bindTexture(gl.TEXTURE_2D, vcTexture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    // debug: print frame properties
    developer.log("frame: ${frame.cols}x${frame.rows} ${frame.channels}");

    final (s, bytes) = cv.imencode(".png", frame);
    frame.dispose();
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, frame.cols, frame.rows, 0,
        gl.RGBA, gl.UNSIGNED_BYTE, bytes);
    gl.begin(GL_QUADS);
    gl.texCoord2f(0.0, 0.0);gl.Vertex2f(-1.0, -1.0);
    gl.texCoord2f(1.0, 0.0);gl.Vertex2f(1.0, -1.0);
    gl.texCoord2f(1.0, 1.0);gl.Vertex2f(1.0, 1.0);
    gl.texCoord2f(0.0, 1.0);gl.Vertex2f(-1.0, 1.0);
    gl.end();
  }

  renderOverlay(){

  }

  render() {
    /**
     * OpenCV Part
     */
    // Read frame from camera
    final (success, frame) = vc.read();
    if (!success) {
      developer.log("Failed to read frame from camera.");
      return;
    }
    // Identify the markers
    // get camera information

    /**
     * OpenGL Part
     */
    final gl = flutterGlPlugin.gl;
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.clearDepth(1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // draw background
    renderBackground(frame);

    gl.viewport(0, 0, (width * dpr).toInt(), (height * dpr).toInt());

    // _gl.bindVertexArray(_vao);
    // _gl.useProgram(glProgram);
    gl.drawArrays(gl.TRIANGLES, 0, n);

    // draw overlay scene

    developer.log(" render n: $n ");

    gl.finish();

    if (!kIsWeb) {
      flutterGlPlugin.updateTexture(sourceTexture);
    }
  }
}
