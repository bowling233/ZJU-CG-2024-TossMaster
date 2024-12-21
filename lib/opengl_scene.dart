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
import 'opengl_sphere.dart' as sphere;
import 'package:vector_math/vector_math.dart' as vm;

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
  // 相机数据及其参数
  // ***********************
  List<CameraDescription> cameras = [];
  CameraController? cameraController;
  late Throttler throttler; // Throttler to limit camera frame rate
  NativeUint8Array? cameraData; // 背景纹理数据
  double fov = 45.0;
  bool cameraFlipH = false, cameraFlipV = false;
  int cameraRotation = 0;

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
  late int bgVao;
  List<dynamic> bgVbo = [];
  late int bgProgram; // 背景着色器
  dynamic bgTexture;
  // 场景用
  late int sceneVao;
  List<dynamic> sceneVbo = [];
  late int sceneProgram;
  late vm.Vector3 cameraPos, cameraFront, cameraUp;
  late vm.Matrix4 pMat;
  sphere.Sphere mySphere = sphere.Sphere();

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
    uniform sampler2D bgTexture;
    void main() {
        color = texture(bgTexture, TexCoord);
    }
    """;
    bgProgram = createShaderProgram(gl, vs, fs);
    // 顶点数据
    // 四个顶点和每个顶点的纹理坐标
    var vertices = Float32Array.fromList([
      // Positions        // Texture Coords
      -1.0, 1.0, 0.0, 0.0, 1.0, // Top Left
      -1.0, -1.0, 0.0, 0.0, 0.0, // Bottom Left
      1.0, -1.0, 0.0, 1.0, 0.0, // Bottom Right
      1.0, 1.0, 0.0, 1.0, 1.0 // Top Right
    ]);
    // 创建并绑定 VBO 和 VAO
    bgVao = gl.createVertexArray();
    gl.bindVertexArray(bgVao);
    bgVbo.add(gl.createBuffer());
    gl.bindBuffer(gl.ARRAY_BUFFER, bgVbo[0]);
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
    // 创建纹理
    // 注意：数据由异步线程传递
    bgTexture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, bgTexture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  }

  renderBackground() {
    final gl = flutterGlPlugin.gl;
    gl.useProgram(bgProgram);
    // 绑定纹理
    gl.bindTexture(gl.TEXTURE_2D, bgTexture);
    // 传递纹理数据
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, (width * dpr).toInt(), (height * dpr).toInt(), 0,
        gl.RGB, gl.UNSIGNED_BYTE, cameraData);
    // 设置纹理单元
    gl.activeTexture(gl.TEXTURE0);
    gl.uniform1i(gl.getUniformLocation(bgProgram, 'bgTexture'), 0);
    // 绘制
    gl.bindVertexArray(bgVao);
    gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
  }

  // 场景
  prepareScene() {
    final gl = flutterGlPlugin.gl;
    // **********
    // 顶点
    // **********
    List<int> ind = mySphere.getIndices();
    List<vm.Vector3> vert = mySphere.getVertices();
    List<vm.Vector2> tex = mySphere.getTexCoords();
    List<vm.Vector3> norm = mySphere.getNormals();

    List<double> pvalues = [];
    List<double> tvalues = [];
    List<double> nvalues = [];

    int numIndices = mySphere.getNumIndices();
    for (int i = 0; i < numIndices; i++) {
      pvalues.add(vert[ind[i]].x);
      pvalues.add(vert[ind[i]].y);
      pvalues.add(vert[ind[i]].z);
      tvalues.add(tex[ind[i]].x);
      tvalues.add(tex[ind[i]].y);
      nvalues.add(norm[ind[i]].x);
      nvalues.add(norm[ind[i]].y);
      nvalues.add(norm[ind[i]].z);
    }

    sceneVao = gl.createVertexArray();
    gl.bindVertexArray(sceneVao);

    sceneVbo.add(gl.createBuffer());
    gl.bindBuffer(gl.ARRAY_BUFFER, sceneVbo[0]);
    gl.bufferData(gl.ARRAY_BUFFER, pvalues.length * Float32List.bytesPerElement,
        Float32List.fromList(pvalues), gl.STATIC_DRAW);

    sceneVbo.add(gl.createBuffer());
    gl.bindBuffer(gl.ARRAY_BUFFER, sceneVbo[1]);
    gl.bufferData(gl.ARRAY_BUFFER, tvalues.length * Float32List.bytesPerElement,
        Float32List.fromList(tvalues), gl.STATIC_DRAW);

    sceneVbo.add(gl.createBuffer());
    gl.bindBuffer(gl.ARRAY_BUFFER, sceneVbo[2]);
    gl.bufferData(gl.ARRAY_BUFFER, nvalues.length * Float32List.bytesPerElement,
        Float32List.fromList(nvalues), gl.STATIC_DRAW);

    // **********
    // 着色器
    // **********
    String version = "300 es";
    if (!kIsWeb) {
      if (Platform.isMacOS || Platform.isWindows) {
        version = "150";
      }
    }
    var vs = """#version $version

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 tex_coord;
out vec2 tc;

uniform mat4 mv_matrix;
uniform mat4 proj_matrix;
//layout (binding=0) uniform sampler2D s;
out vec4 varyingColor;

void main(void)
{	gl_Position = proj_matrix * mv_matrix * vec4(position,1.0);
varyingColor = vec4(position, 1.0) * 0.5 + vec4(0.5, 0.5, 0.5, 0.5);
	//tc = tex_coord;
}
""";

    var fs = """#version $version

in vec2 tc;
out vec4 color;
in vec4 varyingColor;

uniform mat4 mv_matrix;
uniform mat4 proj_matrix;
layout (binding=0) uniform sampler2D s;

void main(void)
{	//color = texture(s,tc);
  //color = vec4(1.0, 0.0, 0.0, 1.0);
  color = varyingColor;
}
""";

    sceneProgram = createShaderProgram(gl, vs, fs);

    // **********
    // 相机
    // **********
    cameraPos = vm.Vector3(0.0, 0.0, 12.0);
    cameraFront = vm.Vector3(0.0, 0.0, -1.0);
    cameraUp = vm.Vector3(0.0, 1.0, 0.0);
  }

  renderScene() {
    final gl = flutterGlPlugin.gl;
    gl.useProgram(sceneProgram);

    var mvLoc = gl.getUniformLocation(sceneProgram, "mv_matrix");
    var projLoc = gl.getUniformLocation(sceneProgram, "proj_matrix");

    pMat =
        vm.makePerspectiveMatrix(vm.radians(fov), width / height, 0.1, 1000.0);
    var vMat = vm.makeViewMatrix(cameraPos, cameraPos + cameraFront, cameraUp);
    var mMat = vm.Matrix4.identity();
    var mvMat = vMat * mMat;
    gl.uniformMatrix4fv(mvLoc, false, mvMat.storage);
    gl.uniformMatrix4fv(projLoc, false, pMat.storage);

    gl.bindVertexArray(sceneVao);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(0);
    gl.bindBuffer(gl.ARRAY_BUFFER, sceneVbo[1]);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 0, 0);
    gl.bindBuffer(gl.ARRAY_BUFFER, sceneVbo[2]);
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 3, gl.FLOAT, false, 0, 0);

    gl.drawArrays(gl.TRIANGLES, 0, mySphere.getNumIndices());
  }

  render() {
    final gl = flutterGlPlugin.gl;
    // 清理
    int current = DateTime.now().millisecondsSinceEpoch;
    gl.viewport(0, 0, (width * dpr).toInt(), (height * dpr).toInt());
    num blue = sin((current - t) / 500);
    // gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.clearColor(1.0, 0.0, blue, 1.0);
    gl.clearDepth(1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // 绘制
    if (cameraData != null) {
      renderBackground();
    }
    renderScene();

    // 上屏
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
          "[_setupCameraController] selected camera: ${cameraDescription.name} ${cameraDescription.lensDirection}");

      setState(() {
        cameraController = CameraController(
          cameraDescription,
          ResolutionPreset.veryHigh,
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
        // debug: print camera properties
        developer.log(
            "[_setupCameraController] ${cameraController?.value.previewSize} ");
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

    throttler = Throttler(milliSeconds: 33);
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

    prepareBackground();
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

    developer.log("[initSize] screenSize: $screenSize dpr: $dpr ");

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
          int x = ((processedImage.width - (width * dpr).toInt()) ~/ 2);
          int y = ((processedImage.height - (height * dpr).toInt()) ~/ 2);
          processedImage = imglib.copyCrop(processedImage,
              x: x,
              y: y,
              width: (width * dpr).toInt(),
              height: (height * dpr).toInt());
          if (cameraFlipH) {
            processedImage = imglib.flipHorizontal(processedImage);
          }
          if (cameraFlipV) {
            processedImage = imglib.flipVertical(processedImage);
          }
          if (cameraRotation != 0) {
            processedImage =
                imglib.copyRotate(processedImage, angle: cameraRotation);
          }

          setState(() {
            cameraData = NativeUint8Array.from(processedImage.toUint8List());
          });

          // debug: print image and data properties
          // developer.log(
          //     "[startImageStream] image: ${processedImage.width}x${processedImage.height} ${processedImage.format}");
          // developer.log("[startImageStream] cameraData: ${cameraData!.length}");
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
