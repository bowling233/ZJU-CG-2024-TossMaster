import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'package:flutter_gl/native-array/NativeArray.app.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:file_picker/file_picker.dart';

import 'opengl_utils.dart';
import 'opengl_model.dart';

enum Mode { editScene, game, editLight, editCamera }

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

class TossMasterApp extends StatelessWidget {
  const TossMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TossMaster - ZJU CG 2024',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TossMaster(),
    );
  }
}

class TossMaster extends StatefulWidget {
  const TossMaster({super.key});
  @override
  State<TossMaster> createState() => _TossMasterState();
}

class _TossMasterState extends State<TossMaster> with WidgetsBindingObserver {
  // ***********************
  // UI
  // - OpenGL 场景
  // - 控制面板
  //   - 模式控制面板
  //   - 模式切换
  // ***********************
  Mode _mode = Mode.editCamera;
  // imglib.Image? testData;
  int? _selectedModelIndex, _selectedModelInstanceIndex;
  double tMin = double.infinity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('TossMaster - ZJU CG 2024'),
      ),
      body: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              // OpenGL 场景
              GestureDetector(
                child: _build(context),
                // 单击：选中/取消选中物体
                onTapUp: (TapUpDetails event) => setState(() {
                  developer.log("onTapUp");
                  // 如果已选中特定实例，则取消选中
                  if (_selectedModelIndex != null &&
                      _selectedModelInstanceIndex != null) {
                    models[_selectedModelIndex!].unSelect();
                    _selectedModelInstanceIndex = null;
                    return;
                  }

                  // 重置选中结果
                  _selectedModelIndex = _selectedModelInstanceIndex = null;
                  tMin = double.infinity;
                  ({int index, double t}) testResult =
                      (index: -1, t: double.infinity);
                  for (var i = 0; i < models.length; i++) {
                    var myResult = models[i].hisTest(
                        screenToNDC(
                            vm.Vector2(
                                event.localPosition.dx, event.localPosition.dy),
                            vm.Vector2(width, height)),
                        cameraPos,
                        vMat,
                        pMat);
                    if (myResult.t < testResult.t) {
                      testResult = myResult;
                      _selectedModelIndex = i;
                      _selectedModelInstanceIndex = testResult.index;
                    }
                  }
                }),
                // 拖动：移动物体
                onPanUpdate: (DragUpdateDetails event) => setState(() {
                  developer
                      .log("onPanUpdate ${event.localPosition} ${event.delta}");
                  // 要求已选中特定实例
                  if (_selectedModelIndex == null ||
                      _selectedModelInstanceIndex == null) {
                    return;
                  }

                  // 移动物体，参考相机坐标系
                  var cameraRight = cameraFront.cross(cameraUp);
                  cameraRight.normalize();
                  var delta = cameraRight * (event.delta.dx) +
                      cameraUp * (-event.delta.dy);

                  models[_selectedModelIndex!].transform(
                      _selectedModelInstanceIndex!,
                      vm.Matrix4.translation(delta * 0.01));
                }),
              ),
              // Container(
              //     child: _pointerEvent != null
              //         ? Column(children: [
              //             Text(
              //                 "x: ${_pointerEvent!.localPosition.dx * dpr}, y: ${_pointerEvent!.localPosition.dy * dpr}"),
              //             Text(
              //                 "selectedModelIndex: $_selectedModelIndex, selectedModelInstanceIndex: $_selectedModelInstanceIndex")
              //           ])
              //         : Container()),
              // 模式控制面板
              _modeWidget,
              const Spacer(),
              // 模式切换
              SegmentedButton<Mode>(
                segments: const <ButtonSegment<Mode>>[
                  ButtonSegment<Mode>(
                    value: Mode.editCamera,
                    label: Text('相机'),
                    icon: Icon(Icons.camera),
                  ),
                  ButtonSegment<Mode>(
                    value: Mode.editScene,
                    label: Text('场景'),
                    icon: Icon(Icons.edit),
                  ),
                  ButtonSegment<Mode>(
                    value: Mode.editLight,
                    label: Text('光照'),
                    icon: Icon(Icons.lightbulb),
                  ),
                  ButtonSegment<Mode>(
                    value: Mode.game,
                    label: Text('游戏'),
                    icon: Icon(Icons.gamepad),
                  ),
                ],
                selected: <Mode>{_mode},
                onSelectionChanged: (Set<Mode> newSelection) {
                  setState(() {
                    _mode = newSelection.first;
                  });
                },
              )
            ]),
      ),
    );
  }

  importModel(gl) async {
    late String objPath, texPath;
    String? gifPath;

    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      objPath = result.files.single.path!;
    }

    result = await FilePicker.platform.pickFiles();
    if (result != null) {
      texPath = result.files.single.path!;
    }

    result = await FilePicker.platform.pickFiles();
    if (result != null) {
      gifPath = result.files.single.path!;
    }

    models.add(ImportedModel(gl, objPath, texPath, gifPath: gifPath));
    setState(() {});
  }

  final Queue<Timer> _timers = Queue<Timer>();

  startMoveVector(vm.Vector3 v, vm.Vector3 dir, double vol) {
    _timers.addLast(Timer.periodic(const Duration(milliseconds: 100), (_) {
      v = moveVector(v, dir, vol);
      setState(() {});
    }));
  }

  stopMoveVector() {
    if (_timers.isNotEmpty) _timers.removeFirst().cancel();
  }

  Widget get _modeWidget {
    switch (_mode) {
      // 相机编辑模式：串流、三轴位移和旋转
      case Mode.editCamera:
        return Scrollbar(
            child: SingleChildScrollView(
                child: Column(children: <Widget>[
          // 串流控制
          ElevatedButton.icon(
            icon: const Icon(Icons.camera),
            onPressed: streamCameraImage,
            label: const Text('相机串流'),
          ),
          // 调试：相机参数
          // Text("cameraPos: $cameraPos"),
          // Text("cameraFront: $cameraFront"),
          // Text("cameraUp: $cameraUp"),
          // Text("cameraVelocity: $cameraVelocity"),
          // 速度调整
          // 速度调整
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.fast_rewind),
                onPressed: () {},
                label: const Text('减速'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  cameraVelocity -= 0.01;
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.fast_forward),
                onPressed: () {},
                label: const Text('加速'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  cameraVelocity += 0.01;
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
          ]),
          // 前进后退
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.zoom_out_map),
                onPressed: () {},
                label: const Text('前进'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  var tmp = cameraFront;
                  tmp.normalize();
                  tmp.scale(cameraVelocity);
                  cameraPos += tmp;
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.zoom_in_map),
                onPressed: () {},
                label: const Text('后退'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  var tmp = cameraFront;
                  tmp.normalize();
                  tmp.scale(cameraVelocity);
                  cameraPos -= tmp;
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
          ]),
          // 上下
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_upward),
                onPressed: () {},
                label: const Text('上升'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  var tmp = cameraUp;
                  tmp.normalize();
                  tmp.scale(cameraVelocity);
                  cameraPos += tmp;
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_downward),
                onPressed: () {},
                label: const Text('下降'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  var tmp = cameraUp;
                  tmp.normalize();
                  tmp.scale(cameraVelocity);
                  cameraPos -= tmp;
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
          ]),
          // 左右
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {},
                label: const Text('左移'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  var carmeraRight = cameraFront.cross(cameraUp);
                  carmeraRight.normalize();
                  carmeraRight.scale(cameraVelocity);
                  cameraPos += carmeraRight;
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {},
                label: const Text('右移'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  var carmeraRight = cameraFront.cross(cameraUp);
                  carmeraRight.normalize();
                  carmeraRight.scale(cameraVelocity);
                  cameraPos -= carmeraRight;
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
          ]),
          // 水平旋转
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.rotate_left),
                onPressed: () {},
                label: const Text('左转'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  var tmp = vm.Matrix4.identity();
                  tmp.rotate(cameraUp, vm.radians(5.0 * cameraVelocity));
                  cameraFront = tmp.transform3(cameraFront);
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.rotate_right),
                onPressed: () {},
                label: const Text('右转'),
              ),
              onTapDown: (_) {
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  var tmp = vm.Matrix4.identity();
                  tmp.rotate(cameraUp, vm.radians(-5.0 * cameraVelocity));
                  cameraFront = tmp.transform3(cameraFront);
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
              },
            ),
          ]),
        ])));
      // 场景编辑模式
      case Mode.editScene:
        return Column(children: <Widget>[
          // 模型管理
          Row(children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              onPressed: () {
                importModel(flutterGlPlugin.gl);
              },
              label: const Text('导入模型'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              onPressed: _selectedModelIndex != null
                  ? () {
                      models[_selectedModelIndex!].instantiate(
                          flutterGlPlugin.gl,
                          vm.Matrix4.translation(vm.Vector3(0, 0, 0)));
                    }
                  : null,
              label: const Text('添加实例'),
            )
          ]),
          // 模型展示与选择
          SizedBox(
              height: 150.0,
              child: ListView.builder(
                itemCount: models.length,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedModelIndex = index;
                      });
                    },
                    child: Card(
                      elevation: 4.0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                      child: Container(
                        color: _selectedModelIndex == index
                            ? Colors.red
                            : Colors.transparent,
                        padding: _selectedModelIndex == index
                            ? const EdgeInsets.all(8.0)
                            : null,
                        child: models[index].gifPath == null
                            ? Image.file(File(models[index].texPath))
                            : Image.file(File(models[index].gifPath!)),
                      ),
                    ),
                  );
                },
              ))
        ]);
      // 光照编辑模式
      case Mode.editLight:
        return Container();
      // 游戏模式
      case Mode.game:
        return Column(
          children: [
            // 投掷按钮
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              onPressed: () {},
              label: const Text('添加模型'),
            ),
          ],
        );
    }
  }

  // ***********************
  // 相机
  // ***********************
  List<CameraDescription> cameras = [];
  CameraController? cameraController;
  late Throttler throttler; // Throttler to limit camera frame rate
  NativeUint8Array? cameraData; // 背景纹理数据
  double fov = 45.0;
  bool cameraFlipH = false, cameraFlipV = false;
  int cameraRotation = 0;
  double cameraVelocity = 0.1;

  void streamCameraImage() {
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

          cameraData = NativeUint8Array.from(processedImage.toUint8List());
          // setState(() {});

          // debug: print image and data properties
          developer.log(
              "[startImageStream] image: ${processedImage.width}x${processedImage.height} ${processedImage.format}");
          developer.log("[startImageStream] cameraData: ${cameraData!.length}");
        });
      });
    } else {
      cameraController?.stopImageStream();
      cameraData = null;
    }
  }

  // ***********************
  // Camera Part
  // ***********************

  // ***********************
  // OpenGL Part
  // ***********************
  // 模型库
  List<ImportedModel> models = [];
  int currentModelIndex = 0;
  // 基本
  late FlutterGlPlugin flutterGlPlugin;
  int? fboId;
  num dpr = 1.0;
  Size? screenSize;
  late double width;
  late double height;
  // 离屏渲染用
  dynamic sourceTexture;
  dynamic defaultFbo;
  dynamic defaultFboTex;
  // 背景用
  late int bgVao;
  List<dynamic> bgVbo = [];
  late int bgProgram; // 背景着色器
  dynamic bgTexture;
  // 场景用
  late int sceneProgram;
  vm.Vector3 cameraPos = vm.Vector3(0.0, 0.0, 12.0),
      cameraFront = vm.Vector3(0.0, 0.0, -1.0),
      cameraUp = vm.Vector3(0.0, 1.0, 0.0);
  late vm.Matrix4 pMat;
  late vm.Matrix4 vMat =
      vm.makeViewMatrix(cameraPos, cameraPos + cameraFront, cameraUp);
  //sphere.Sphere mySphere = sphere.Sphere();

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

  // 背景纹理渲染
  renderBackground() {
    final gl = flutterGlPlugin.gl;
    gl.useProgram(bgProgram);
    // 禁用深度测试
    gl.disable(gl.DEPTH_TEST);
    // 绑定纹理
    gl.bindTexture(gl.TEXTURE_2D, bgTexture);
    // 传递纹理数据
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, (width * dpr).toInt(),
        (height * dpr).toInt(), 0, gl.RGB, gl.UNSIGNED_BYTE, cameraData);
    // 设置纹理单元
    gl.activeTexture(gl.TEXTURE0);
    gl.uniform1i(gl.getUniformLocation(bgProgram, 'bgTexture'), 0);
    // 绘制
    gl.bindVertexArray(bgVao);
    gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
  }

  // 场景数据准备
  prepareScene() async {
    final gl = flutterGlPlugin.gl;
    // 顶点

    // late String objPath, texPath;
    // FilePickerResult? result = await FilePicker.platform.pickFiles();
    // if (result != null) {
    //   developer.log("selected file: ${result.files.single.path}");
    //   objPath = result.files.single.path!;
    // }

    // // 纹理
    // result = await FilePicker.platform.pickFiles();
    // if (result != null) {
    //   developer.log("selected file: ${result.files.single.path}");
    //   texPath = result.files.single.path!;
    // }

    // models.add(ImportedModel(gl, objPath, texPath));
    // models[0].instantiate(gl, vm.Matrix4.translation(vm.Vector3(0, 0, 0)));
    // models[0].instantiate(gl, vm.Matrix4.translation(vm.Vector3(2, 0, 0)));
    // models[0].instantiate(gl, vm.Matrix4.translation(vm.Vector3(0, 2, 0)));

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

layout (location = 0) in vec3 vertPos;
layout (location = 1) in vec2 tex_coord;
layout (location = 2) in vec3 vertNormal;
layout (location = 3) in mat4 instanceMatrix;
layout (location = 7) in int instanceFlag;
out vec3 varyingNormal;
out vec3 varyingLightDir;
out vec3 varyingVertPos;
out vec3 varyingHalfVector;
out vec2 tc;
flat out int flag;

struct PositionalLight
{	vec4 ambient;
	vec4 diffuse;
	vec4 specular;
	vec3 position;
};
struct Material
{	vec4 ambient;
	vec4 diffuse;
	vec4 specular;
	float shininess;
};

uniform vec4 globalAmbient;
uniform PositionalLight light;
uniform Material material;
uniform mat4 v_matrix;
uniform mat4 proj_matrix;
uniform mat4 norm_matrix;
layout (binding=0) uniform sampler2D s;

void main(void)
{	varyingVertPos = (v_matrix * instanceMatrix * vec4(vertPos,1.0)).xyz;
	varyingLightDir = light.position - varyingVertPos;
	varyingNormal = (norm_matrix * vec4(vertNormal,1.0)).xyz;

	varyingHalfVector =
		normalize(normalize(varyingLightDir)
		+ normalize(-varyingVertPos)).xyz;

	gl_Position = proj_matrix * v_matrix * instanceMatrix * vec4(vertPos,1.0);
	tc = tex_coord;
  flag = instanceFlag;
}

""";

    var fs = """#version $version

in vec3 varyingNormal;
in vec3 varyingLightDir;
in vec3 varyingVertPos;
in vec3 varyingHalfVector;
in vec2 tc;
flat in int flag;

out vec4 fragColor;

struct PositionalLight
{	vec4 ambient;
	vec4 diffuse;
	vec4 specular;
	vec3 position;
};

struct Material
{	vec4 ambient;
	vec4 diffuse;
	vec4 specular;
	float shininess;
};

uniform vec4 globalAmbient;
uniform PositionalLight light;
uniform Material material;
uniform mat4 v_matrix;
uniform mat4 proj_matrix;
uniform mat4 norm_matrix;
layout (binding=0) uniform sampler2D s;

void main(void)
{	// normalize the light, normal, and view vectors:
	// vec3 L = normalize(varyingLightDir);
	// vec3 N = normalize(varyingNormal);
	// vec3 V = normalize(-varyingVertPos);

	// // get the angle between the light and surface normal:
	// float cosTheta = dot(L,N);

	// // halfway vector varyingHalfVector was computed in the vertex shader,
	// // and interpolated prior to reaching the fragment shader.
	// // It is copied into variable H here for convenience later.
	// vec3 H = normalize(varyingHalfVector);

	// // get angle between the normal and the halfway vector
	// float cosPhi = dot(H,N);

	// // compute ADS contributions (per pixel):
	// vec3 ambient = ((globalAmbient * material.ambient) + (light.ambient * material.ambient)).xyz;
	// vec3 diffuse = light.diffuse.xyz * material.diffuse.xyz * max(cosTheta,0.0);
	// vec3 specular = light.specular.xyz * material.specular.xyz * pow(max(cosPhi,0.0), material.shininess*3.0);
	// fragColor = vec4((ambient + diffuse + specular), 1.0);
  if(flag == 1)
    // highlight selected model
    fragColor = vec4(1.0, 0.0, 0.0, 1.0);
  else
    fragColor = texture(s, tc);
}
""";

    sceneProgram = createShaderProgram(gl, vs, fs);
  }

  renderScene() {
    final gl = flutterGlPlugin.gl;
    gl.useProgram(sceneProgram);

    // 深度测试和剔除
    gl.enable(gl.DEPTH_TEST);
    gl.depthFunc(gl.LEQUAL);
    gl.enable(gl.CULL_FACE);
    gl.frontFace(gl.CCW);

    // 矩阵统一变量
    var vLoc = gl.getUniformLocation(sceneProgram, "v_matrix");
    var projLoc = gl.getUniformLocation(sceneProgram, "proj_matrix");
    var normLoc = gl.getUniformLocation(sceneProgram, "norm_matrix");

    // 投影矩阵
    pMat =
        vm.makePerspectiveMatrix(vm.radians(fov), width / height, 0.1, 1000.0);
    gl.uniformMatrix4fv(projLoc, false, pMat.storage);
    // 视图矩阵
    vMat = vm.makeViewMatrix(cameraPos, cameraPos + cameraFront, cameraUp);
    gl.uniformMatrix4fv(vLoc, false, vMat.storage);

    for (final model in models) {
      model.render(gl);
    }
  }

  render() {
    final gl = flutterGlPlugin.gl;
    int current = DateTime.now().millisecondsSinceEpoch;
    num blue = (sin((current - t) / 200) + 1) / 2;
    num green = (cos((current - t) / 300) + 1) / 2;
    num red = (sin((current - t) / 400) + cos((current - t) / 500) + 2) / 4;

    // 清理
    // gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.clearColor(red, green, blue, 1.0);
    gl.clearDepth(1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // 离屏渲染：设置绘图区域为 FBO 大小
    gl.viewport(0, 0, (width * dpr).toInt(), (height * dpr).toInt());

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

  setup() async {
    // web no need use fbo
    if (!kIsWeb) {
      await flutterGlPlugin.prepareContext();

      setupDefaultFBO();
      sourceTexture = defaultFboTex;
    }

    setState(() {});

    prepareBackground();
    await prepareScene();

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

    developer.log("[initSize] screenSize: $screenSize dpr: $dpr ");

    initPlatformState();
  }

  Widget _build(BuildContext context) {
    initSize(context);

    return Container(
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
        }));
  }

  // 创建 FBO 用于离屏渲染
  setupDefaultFBO() {
    final gl = flutterGlPlugin.gl;
    int glWidth = (width * dpr).toInt();
    int glHeight = (height * dpr).toInt();

    developer.log("glWidth: $glWidth glHeight: $glHeight ");

    // 离屏渲染用 FBO
    defaultFbo = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, defaultFbo);
    // 颜色纹理附件
    defaultFboTex = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, defaultFboTex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, glWidth, glHeight, 0, gl.RGBA,
        gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.framebufferTexture2D(
        gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, defaultFboTex, 0);
    // 缓冲对象附件
    var defaultFboRbo = gl.createRenderbuffer();
    gl.bindRenderbuffer(gl.RENDERBUFFER, defaultFboRbo);
    gl.renderbufferStorage(
        gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, glWidth, glHeight);
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT,
        gl.RENDERBUFFER, defaultFboRbo);
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
