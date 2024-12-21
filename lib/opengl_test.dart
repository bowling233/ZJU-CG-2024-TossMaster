import 'dart:async';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'opengl_utils.dart';
import 'opengl_sphere.dart' as sphere;

class OpenGLScene extends StatefulWidget {
  const OpenGLScene({super.key});
  @override
  State<OpenGLScene> createState() => _OpenGLSceneState();
}

class _OpenGLSceneState extends State<OpenGLScene> with WidgetsBindingObserver {
  // ***********************
  // OpenGL Part
  // ***********************
  late FlutterGlPlugin flutterGlPlugin;
  int? fboId;
  num dpr = 1.0;
  Size? screenSize;
  late double width;
  late double height;
  double fov = 45.0;
  // 离屏渲染用
  dynamic sourceTexture;
  dynamic defaultFramebuffer;
  dynamic defaultFramebufferTexture;
  // 场景用
  late int sceneVao;
  List<dynamic> sceneVbo = [];
  late int renderingProgram;
  late vm.Vector3 cameraPos, cameraFront, cameraUp;
  late vm.Matrix4 pMat;
  // 背景用

  int t = DateTime.now().millisecondsSinceEpoch;

  sphere.Sphere mySphere = sphere.Sphere();

  // ********************
  // Init State
  // ********************
  setupVertices() {
    final gl = flutterGlPlugin.gl;
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
  }

  init() {
    final gl = flutterGlPlugin.gl;

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

void main(void)
{	gl_Position = proj_matrix * mv_matrix * vec4(position,1.0);
	//tc = tex_coord;
}
""";

    var fs = """#version $version

in vec2 tc;
out vec4 color;

uniform mat4 mv_matrix;
uniform mat4 proj_matrix;
layout (binding=0) uniform sampler2D s;

void main(void)
{	//color = texture(s,tc);
  color = vec4(1.0, 0.0, 0.0, 1.0);
}
""";

    renderingProgram = createShaderProgram(gl, vs, fs);

    cameraPos = vm.Vector3(0.0, 0.0, 12.0);
    cameraFront = vm.Vector3(0.0, 0.0, -1.0);
    cameraUp = vm.Vector3(0.0, 1.0, 0.0);

    setupVertices();
  }

  @override
  void initState() {
    super.initState();
  }

  // ********************
  // Build (Prepare)
  // ********************

  // 创建 FBO 用于离屏渲染
  setupDefaultFBO() {
    final gl = flutterGlPlugin.gl;
    int glWidth = (width * dpr).toInt();
    int glHeight = (height * dpr).toInt();

    dev.log("glWidth: $glWidth glHeight: $glHeight ");

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

  setup() async {
    // web no need use fbo
    if (!kIsWeb) {
      await flutterGlPlugin.prepareContext();

      setupDefaultFBO();
      sourceTexture = defaultFramebufferTexture;
    }

    setState(() {});
    animate();
  }

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

    dev.log(" flutterGlPlugin: textureid: ${flutterGlPlugin.textureId} ");

    setState(() {});

    // web need wait dom ok!!!
    Future.delayed(const Duration(milliseconds: 100), () {
      setup();
    });
  }

  initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mq = MediaQuery.of(context);

    screenSize = mq.size;
    dpr = mq.devicePixelRatio;

    dev.log(" screenSize: $screenSize dpr: $dpr ");

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

  // ********************
  // Animate
  // ********************
  display() {
    final gl = flutterGlPlugin.gl;
    // gl.viewport(0, 0, (width * dpr).toInt(), (height * dpr).toInt());
    // gl.clearDepth(1);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    gl.useProgram(renderingProgram);

    var mvLoc = gl.getUniformLocation(renderingProgram, "mv_matrix");
    var projLoc = gl.getUniformLocation(renderingProgram, "proj_matrix");

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

    gl.finish();

    if (!kIsWeb) {
      flutterGlPlugin.updateTexture(sourceTexture);
    }
  }

  animate() {
    init();
    display();

    Future.delayed(const Duration(milliseconds: 33), () {
      animate();
    });
  }
}
