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
import 'package:sensors_plus/sensors_plus.dart';
// import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'opengl_utils.dart';
import 'opengl_model.dart';
import 'opengl_sphere.dart' as sphere;

vm.Vector3 gravity = vm.Vector3(0.0, -9.8, 0.0);

enum ControlMode { editScene, game, editLight, editCamera }

enum GameMode { pre, act, over }

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
  // ***************************************************************
  // UI
  // ***************************************************************
  ControlMode _controlMode = ControlMode.editCamera;
  // imglib.Image? testData;
  int? _selectedModelIndex, _selectedModelInstanceIndex;
  double tMin = double.infinity;
  double lastScale = 1.0, lastRotation = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('TossMaster - ZJU CG 2024'),
      ),
      body: SingleChildScrollView(
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
                    _models[_selectedModelIndex!].unSelect();
                    _selectedModelInstanceIndex = null;
                    return;
                  }
                  // 重置选中结果
                  _selectedModelIndex = _selectedModelInstanceIndex = null;
                  tMin = double.infinity;
                  ({int index, double t}) testResult =
                      (index: -1, t: double.infinity);
                  developer.log("${_models.length}");
                  for (var i = 0; i < _models.length; i++) {
                    developer.log("i: $i");
                    var myResult = _models[i].hitTest(
                        screenToNDC(
                            vm.Vector2(
                                event.localPosition.dx, event.localPosition.dy),
                            vm.Vector2(width, height)),
                        cameraPos,
                        vMat,
                        pMat);
                    developer.log(
                        "myResult: $myResult, tMin: $tMin, testResult: $testResult");
                    if (myResult.t < testResult.t) {
                      testResult = myResult;
                      _selectedModelIndex = i;
                      _selectedModelInstanceIndex = testResult.index;
                    }
                  }
                  // 选中模型
                  if (_selectedModelIndex != null &&
                      _selectedModelInstanceIndex != null) {
                    _models[_selectedModelIndex!]
                        .select(_selectedModelInstanceIndex!);
                  }
                }),
                // Scale 手势：包含移动、旋转和缩放
                onScaleStart: (ScaleStartDetails event) {
                  // 重置差值
                  lastScale = 1.0;
                  lastRotation = 0.0;
                },
                onScaleUpdate: (ScaleUpdateDetails event) => setState(() {
                  developer.log(
                      "onScaleUpdate ${event.scale} ${event.focalPointDelta} ${event.rotation}");
                  // 要求已选中特定实例
                  if (_selectedModelIndex == null ||
                      _selectedModelInstanceIndex == null) {
                    return;
                  }

                  // 移动向量
                  var cameraRight = cameraFront.cross(cameraUp);
                  cameraRight.normalize();
                  var positionDelta =
                      cameraRight * (event.focalPointDelta.dx * 0.01) +
                          cameraUp * (-event.focalPointDelta.dy * 0.01);

                  // 旋转四元数
                  var rotationDelta = vm.Quaternion.axisAngle(cameraUp,
                      vm.radians((event.rotation - lastRotation) * 50));
                  lastRotation = event.rotation;

                  // 缩放比例差值
                  var scaleDiff = (event.scale - lastScale);
                  lastScale = event.scale;
                  developer.log("scaleDiff: $scaleDiff");

                  _models[_selectedModelIndex!].transform(
                      _selectedModelInstanceIndex!,
                      positionDelta,
                      rotationDelta,
                      scaleDiff);
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
              // 模式切换
              SegmentedButton<ControlMode>(
                segments: const <ButtonSegment<ControlMode>>[
                  ButtonSegment<ControlMode>(
                    value: ControlMode.editCamera,
                    label: Text('相机'),
                    icon: Icon(Icons.camera),
                  ),
                  ButtonSegment<ControlMode>(
                    value: ControlMode.editScene,
                    label: Text('场景'),
                    icon: Icon(Icons.edit),
                  ),
                  ButtonSegment<ControlMode>(
                    value: ControlMode.editLight,
                    label: Text('光照'),
                    icon: Icon(Icons.lightbulb),
                  ),
                  ButtonSegment<ControlMode>(
                    value: ControlMode.game,
                    label: Text('游戏'),
                    icon: Icon(Icons.gamepad),
                  ),
                ],
                selected: <ControlMode>{_controlMode},
                onSelectionChanged: (Set<ControlMode> newSelection) {
                  setState(() {
                    _controlMode = newSelection.first;
                  });
                },
              ),
              // 模式控制面板
              _modeControlWidget,
            ]),
      ),
    );
  }

  importModel(gl) async {
    late String objPath;
    String? gifPath, texPath;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('导入模型'),
          content: const Text(
              '请依次选择 obj、tex 和 gif 文件。如果没有 tex 或 gif 文件，请留空（即不选择文件，直接返回）。'),
          actions: <Widget>[
            TextButton(
              child: const Text('开始选择文件'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      objPath = result.files.single.path!;
    } else {
      return;
    }

    result = await FilePicker.platform.pickFiles();
    if (result != null) {
      texPath = result.files.single.path!;
    }

    result = await FilePicker.platform.pickFiles();
    if (result != null) {
      gifPath = result.files.single.path!;
    }

    _models.add(ImportedModel(gl, objPath, texPath, gifPath));
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

  Widget get _modeControlWidget {
    switch (_controlMode) {
      // 相机编辑模式：串流、三轴位移和旋转
      case ControlMode.editCamera:
        return Column(children: <Widget>[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            // 串流控制
            ElevatedButton.icon(
              icon: const Icon(Icons.camera),
              onPressed: streamCameraImage,
              label: const Text('相机串流'),
            ),
            // 陀螺仪控制
            ElevatedButton.icon(
              icon: const Icon(Icons.gps_fixed),
              onPressed: () => setState(() {
                _listenGyroscope = !_listenGyroscope;
              }),
              label: const Text('陀螺仪'),
            ),
          ]),
          // 调试：相机参数
          // Text(
          //     "Pos: ${cameraPos.x.toInt()}, ${cameraPos.y.toInt()}, ${cameraPos.z.toInt()}"),
          // Text(
          //     "Front: ${cameraFront.x.toInt()}, ${cameraFront.y.toInt()}, ${cameraFront.z.toInt()}"),
          // Text(
          //     "Up: ${cameraUp.x.toInt()}, ${cameraUp.y.toInt()}, ${cameraUp.z.toInt()}"),
          // Text("Velocity: ${cameraVelocity.toInt()}"),
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
            // 重置相机位置和速度
            ElevatedButton.icon(
                icon: const Icon(Icons.restore),
                onPressed: () {
                  cameraPos = vm.Vector3(0.0, 0.0, 12.0);
                  cameraFront = vm.Vector3(0.0, 0.0, -1.0);
                  cameraUp = vm.Vector3(0.0, 1.0, 0.0);
                  cameraVelocity = 0.1;
                  setState(() {});
                },
                label: const Text('重置'))
          ]),
          // 前进后退
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.zoom_out_map),
                onPressed: () {},
                label: const Text('前'),
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
                label: const Text('后'),
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
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_upward),
                onPressed: () {},
                label: const Text('上'),
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
                label: const Text('下'),
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
                label: const Text('左'),
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
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {},
                label: const Text('右'),
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
                icon: const Icon(Icons.rotate_left),
                onPressed: () {},
                label: const Text('左'),
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
                label: const Text('右'),
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
        ]);
      // 场景编辑模式
      case ControlMode.editScene:
        return Column(children: <Widget>[
          // 模型管理
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                      _models[_selectedModelIndex!].instantiate();
                    }
                  : null,
              label: const Text('添加实例'),
            )
          ]),
          // 模型展示与选择
          SizedBox(
              height: 150.0,
              child: ListView.builder(
                itemCount: _models.length,
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
                        child: _models[index].gifPath == null
                            ? (_models[index].texPath == null
                                ? Container(
                                    width: 150,
                                    height: 150,
                                    color: Colors.grey,
                                    child: const Center(
                                      child: Text('No Image'),
                                    ),
                                  )
                                : Image.file(File(_models[index].texPath!)))
                            : Image.file(File(_models[index].gifPath!)),
                      ),
                    ),
                  );
                },
              ))
        ]);
      // 光照编辑模式
      case ControlMode.editLight:
        return Column(
          children: [
            Text("定向光照"),
            // 定向光源位置
            Row(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width / 3,
                  height: MediaQuery.of(context).size.width / 3,
                  child: SfRadialGauge(
                    axes: <RadialAxis>[
                      RadialAxis(
                        minimum: 0,
                        maximum: 360,
                        startAngle: 0,
                        endAngle: 360,
                        showLabels: false,
                        showTicks: false,
                        pointers: <GaugePointer>[
                          MarkerPointer(
                            value: (atan2(lightPos.y, lightPos.x) * 180 / pi) %
                                360,
                            enableDragging: true,
                            markerHeight: 20,
                            markerWidth: 20,
                            markerType: MarkerType.circle,
                            color: Colors.red,
                            onValueChanged: (value) {
                              setState(() {
                                double radians = value * pi / 180;
                                lightPos.x = cos(radians) * lightPos.length;
                                lightPos.y = sin(radians) * lightPos.length;
                              });
                            },
                          ),
                        ],
                        annotations: [
                          GaugeAnnotation(
                            widget: Text("位置"),
                            // angle: 90,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 光源纵向旋转
                SizedBox(
                  width: MediaQuery.of(context).size.width / 3,
                  height: MediaQuery.of(context).size.width / 3,
                  child: SfRadialGauge(
                    axes: <RadialAxis>[
                      RadialAxis(
                        minimum: -90,
                        maximum: 90,
                        startAngle: 0,
                        endAngle: 360,
                        showLabels: false,
                        showTicks: false,
                        pointers: <GaugePointer>[
                          MarkerPointer(
                            value:
                                (asin(lightPos.z / lightPos.length) * 180 / pi),
                            enableDragging: true,
                            markerHeight: 20,
                            markerWidth: 20,
                            markerType: MarkerType.circle,
                            color: Colors.blue,
                            onValueChanged: (value) {
                              setState(() {
                                double radians = value * pi / 180;
                                lightPos.z = sin(radians) * lightPos.length;
                                double xyLength =
                                    cos(radians) * lightPos.length;
                                lightPos.x =
                                    cos(atan2(lightPos.y, lightPos.x)) *
                                        xyLength;
                                lightPos.y =
                                    sin(atan2(lightPos.y, lightPos.x)) *
                                        xyLength;
                              });
                            },
                          ),
                        ],
                        annotations: [
                          GaugeAnnotation(
                            widget: Text("高度"),
                            angle: 90,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 光照颜色
                SizedBox(
                  width: MediaQuery.of(context).size.width / 3,
                  height: MediaQuery.of(context).size.width / 3,
                  child: SfRadialGauge(
                    axes: <RadialAxis>[
                      RadialAxis(
                        minimum: 0,
                        maximum: 1,
                        startAngle: 0,
                        endAngle: 360,
                        showLabels: true,
                        showTicks: false,
                        pointers: <GaugePointer>[
                          MarkerPointer(
                            value: lightColor.red / 255,
                            enableDragging: true,
                            markerHeight: 20,
                            markerWidth: 20,
                            markerType: MarkerType.circle,
                            color: Colors.red,
                            onValueChanged: (value) {
                              setState(() {
                                lightColor = Color.fromARGB(
                                    255,
                                    (value * 255).toInt(),
                                    lightColor.green,
                                    lightColor.blue);
                              });
                            },
                          ),
                          MarkerPointer(
                            value: lightColor.green / 255,
                            enableDragging: true,
                            markerHeight: 20,
                            markerWidth: 20,
                            markerType: MarkerType.circle,
                            color: Colors.green,
                            onValueChanged: (value) {
                              setState(() {
                                lightColor = Color.fromARGB(255, lightColor.red,
                                    (value * 255).toInt(), lightColor.blue);
                              });
                            },
                          ),
                          MarkerPointer(
                            value: lightColor.blue / 255,
                            enableDragging: true,
                            markerHeight: 20,
                            markerWidth: 20,
                            markerType: MarkerType.circle,
                            color: Colors.blue,
                            onValueChanged: (value) {
                              setState(() {
                                lightColor = Color.fromARGB(255, lightColor.red,
                                    lightColor.green, (value * 255).toInt());
                              });
                            },
                          ),
                          RangePointer(
                            value: lightColor.red / 255,
                            color: Colors.red.withOpacity(0.5),
                          ),
                          RangePointer(
                            value: lightColor.green / 255,
                            color: Colors.green.withOpacity(0.5),
                          ),
                          RangePointer(
                            value: lightColor.blue / 255,
                            color: Colors.blue.withOpacity(0.5),
                          ),
                        ],
                        annotations: [
                          GaugeAnnotation(
                            widget: Text("颜色"),
                            angle: 90,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 环境光照强度
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("环境光照强度："),
                Slider(
                  value: globalAmbientStrength,
                  onChanged: (value) {
                    setState(() {
                      globalAmbientStrength = value;
                    });
                  },
                  min: 0.0,
                  max: 1.0,
                ),
              ],
            ),
            // 材质下拉选择
            DropdownMenu<GlMaterialLabel>(
              //initialSelection: _currentMaterial,
              initialSelection: GlMaterialLabel.values[_currentMaterial.index],
              label: const Text("材质"),
              requestFocusOnTap: true,
              onSelected: (GlMaterialLabel? newValue) {
                setState(() {
                  _currentMaterial = GlMaterial.values[newValue!.index];
                });
              },
              dropdownMenuEntries: GlMaterialLabel.entries,
            ),
          ],
        );
      // 游戏模式
      case ControlMode.game:
        return Column(
          children: [
            // 速度显示
            Text("速度：${_sphere.instanceVelocity[0].length}"),
            // 投掷按钮
            GestureDetector(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                onPressed: () {},
                label: const Text('投掷'),
              ),
              // 按下：加速
              onTapDown: (_) {
                _gameMode = GameMode.pre;
                _sphere.instanceVelocity[0] = vm.Vector3.zero();
                _timers.addLast(
                    Timer.periodic(const Duration(milliseconds: 100), (_) {
                  _sphere.instanceVelocity[0] += vm.Vector3.all(1);
                  setState(() {});
                }));
              },
              onTapCancel: () {
                if (_timers.isNotEmpty) _timers.removeFirst().cancel();
                var curr = 0;
                var rMat = vm.Matrix4.identity();
                rMat.rotate(cameraFront.cross(cameraUp), vm.radians(40.0));
                var tmp = vm.Vector3.copy(cameraFront);
                tmp.scale(_sphere.instanceVelocity[curr].length);
                _sphere.instanceVelocity[curr] = rMat.transform3(tmp);
                _gameMode = GameMode.act;
              },
            ),
          ],
        );
    }
  }

  // ***************************************************************
  // OpenGL：Widget 初始化和离屏渲染准备
  // ***************************************************************
  late FlutterGlPlugin flutterGlPlugin;
  num dpr = 1.0;
  Size? screenSize;
  late double width;
  late double height;
  dynamic sourceTexture;
  dynamic defaultFbo;
  dynamic defaultFboTex;
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

  setup() async {
    // web no need use fbo
    if (!kIsWeb) {
      await flutterGlPlugin.prepareContext();

      setupDefaultFBO();
      sourceTexture = defaultFboTex;
    }

    setState(() {});

    prepareBackground();
    prepareScene();

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

  // ***************************************************************
  // OpenGL：背景
  // ***************************************************************
  late int bgProgram;
  late int bgVao;
  List<dynamic> bgVbo = [];
  dynamic bgTexture;
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

  // ***********************
  // OpenGL：场景
  // ***********************
  late int sceneProgram;
  List<ImportedModel> _models = [];
  late sphere.Sphere _sphere;
  prepareScene() {
    final gl = flutterGlPlugin.gl;
    String version = "300 es";
    if (!kIsWeb) {
      if (Platform.isMacOS || Platform.isWindows) {
        version = "150";
      }
    }
    var vs = """#version $version

precision mediump float;
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
uniform sampler2D s;

void main(void)
{	varyingVertPos = (v_matrix * instanceMatrix * vec4(vertPos,1.0)).xyz;
	varyingLightDir = light.position - varyingVertPos;
  mat4 mvMat = v_matrix * instanceMatrix;
  mat4 invTrMat = transpose(inverse(mvMat));
  varyingNormal = (invTrMat * vec4(vertNormal, 0.0)).xyz;

	varyingHalfVector =
		normalize(normalize(varyingLightDir)
		+ normalize(-varyingVertPos)).xyz;

	gl_Position = proj_matrix * mvMat * vec4(vertPos,1.0);
	tc = tex_coord;
  flag = instanceFlag;
}

""";

    var fs = """#version $version

precision mediump float;
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
uniform sampler2D s;

void main(void)
{ // normalize the light, normal, and view vectors:
  vec3 L = normalize(varyingLightDir);
  vec3 N = normalize(varyingNormal);
  vec3 V = normalize(-varyingVertPos);

  // get the angle between the light and surface normal:
  float cosTheta = dot(L,N);

  // halfway vector varyingHalfVector was computed in the vertex shader,
  // and interpolated prior to reaching the fragment shader.
  // It is copied into variable H here for convenience later.
  vec3 H = normalize(varyingHalfVector);

  // get angle between the normal and the halfway vector
  float cosPhi = dot(H,N);

  // compute ADS contributions (per pixel):
  vec4 textureColor = texture(s, tc);
	vec3 ambient = (globalAmbient.xyz + light.ambient.xyz);
	vec3 diffuse = light.diffuse.xyz * max(cosTheta, 0.0);
	vec3 specular = light.specular.xyz * pow(max(cosPhi, 0.0), 51.2 * 3.0);

  if(flag == 1)
    // highlight selected model
    fragColor = vec4(vec3(1.0, 0.0, 0.0) * (ambient + diffuse + specular), 1.0);
  else if(flag == 2)
  {
    // material
    ambient = ((globalAmbient * material.ambient) + (light.ambient * material.ambient)).xyz;
    diffuse = light.diffuse.xyz * material.diffuse.xyz * max(cosTheta,0.0);
    specular = light.specular.xyz * material.specular.xyz * pow(max(cosPhi,0.0), material.shininess*3.0);
    fragColor = vec4((ambient + diffuse + specular), 1.0);
  }
  else
    fragColor = vec4(textureColor.xyz * (ambient + diffuse + specular), textureColor.a);
}
""";

    sceneProgram = createShaderProgram(gl, vs, fs);

    _sphere = sphere.Sphere(gl);
    _sphere.instantiate();
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

    // 投影矩阵
    pMat = vm.makePerspectiveMatrix(
        vm.radians(cameraFov), width / height, 0.1, 1000.0);
    gl.uniformMatrix4fv(projLoc, false, pMat.storage);
    // 视图矩阵
    vMat = vm.makeViewMatrix(cameraPos, cameraPos + cameraFront, cameraUp);
    gl.uniformMatrix4fv(vLoc, false, vMat.storage);

    // 实例化渲染
    for (final model in _models) {
      model.render(gl);
    }

    if (_controlMode == ControlMode.game) _sphere.render(gl);
  }

  // ***************************************************************
  // OpenGL：光照与
  // ***************************************************************
  // 当前选择的材质
  GlMaterial _currentMaterial = GlMaterial.gold;
  // ADS 光照：环境光、漫反射、镜面反射
  // 环境光
  Color globalColor = Colors.white;
  double globalAmbientStrength = 0.7;
  // 定向光
  Color lightColor = Colors.white;
  double lightAmbientStrength = 0.0;
  double lightDiffuseStrength = 1.0;
  double lightSpecularStrength = 1.0;
  vm.Vector3 lightPos = vm.Vector3(5.0, 2.0, 2.0);
  installLights() {
    final gl = flutterGlPlugin.gl;
    gl.useProgram(sceneProgram);
    // List<double> globalAmbient = [0.7, 0.7, 0.7, 1.0];
    // List<double> lightAmbient = [0.0, 0.0, 0.0, 1.0];
    // List<double> lightDiffuse = [1.0, 1.0, 1.0, 1.0];
    // List<double> lightSpecular = [1.0, 1.0, 1.0, 1.0];
    List<double> globalAmbient = [
      globalColor.red / 255 * globalAmbientStrength,
      globalColor.green / 255 * globalAmbientStrength,
      globalColor.blue / 255 * globalAmbientStrength,
      1.0
    ];
    List<double> lightAmbient = [
      lightColor.red / 255 * lightAmbientStrength,
      lightColor.green / 255 * lightAmbientStrength,
      lightColor.blue / 255 * lightAmbientStrength,
      1.0
    ];
    List<double> lightDiffuse = [
      lightColor.red / 255 * lightDiffuseStrength,
      lightColor.green / 255 * lightDiffuseStrength,
      lightColor.blue / 255 * lightDiffuseStrength,
      1.0
    ];
    List<double> lightSpecular = [
      lightColor.red / 255 * lightSpecularStrength,
      lightColor.green / 255 * lightSpecularStrength,
      lightColor.blue / 255 * lightSpecularStrength,
      1.0
    ];
    // 光照
    var transformed = vMat.transform3(vm.Vector3.copy(lightPos));

    final globalAmbLoc = gl.getUniformLocation(sceneProgram, "globalAmbient");
    final ambLoc = gl.getUniformLocation(sceneProgram, "light.ambient");
    final diffLoc = gl.getUniformLocation(sceneProgram, "light.diffuse");
    final specLoc = gl.getUniformLocation(sceneProgram, "light.specular");
    final posLoc = gl.getUniformLocation(sceneProgram, "light.position");
    gl.uniform4fv(globalAmbLoc, NativeFloat32Array.from(globalAmbient));
    gl.uniform4fv(ambLoc, NativeFloat32Array.from(lightAmbient));
    gl.uniform4fv(diffLoc, NativeFloat32Array.from(lightDiffuse));
    gl.uniform4fv(specLoc, NativeFloat32Array.from(lightSpecular));
    gl.uniform3fv(posLoc, transformed.storage);

    //材质

    final mambLoc = gl.getUniformLocation(sceneProgram, "material.ambient");
    final mdiffLoc = gl.getUniformLocation(sceneProgram, "material.diffuse");
    final mspecLoc = gl.getUniformLocation(sceneProgram, "material.specular");
    final mshinyLoc = gl.getUniformLocation(sceneProgram, "material.shininess");

    switch (_currentMaterial) {
      case GlMaterial.gold:
        gl.uniform4fv(mambLoc, NativeFloat32Array.from(goldAmbient));
        gl.uniform4fv(mdiffLoc, NativeFloat32Array.from(goldDiffuse));
        gl.uniform4fv(mspecLoc, NativeFloat32Array.from(goldSpecular));
        gl.uniform1f(mshinyLoc, goldShininess);
        break;
      case GlMaterial.silver:
        gl.uniform4fv(mambLoc, NativeFloat32Array.from(silverAmbient));
        gl.uniform4fv(mdiffLoc, NativeFloat32Array.from(silverDiffuse));
        gl.uniform4fv(mspecLoc, NativeFloat32Array.from(silverSpecular));
        gl.uniform1f(mshinyLoc, silverShininess);
        break;
      case GlMaterial.bronze:
        gl.uniform4fv(mambLoc, NativeFloat32Array.from(bronzeAmbient));
        gl.uniform4fv(mdiffLoc, NativeFloat32Array.from(bronzeDiffuse));
        gl.uniform4fv(mspecLoc, NativeFloat32Array.from(bronzeSpecular));
        gl.uniform1f(mshinyLoc, bronzeShininess);
        break;
      case GlMaterial.jade:
        gl.uniform4fv(mambLoc, NativeFloat32Array.from(jadeAmbient));
        gl.uniform4fv(mdiffLoc, NativeFloat32Array.from(jadeDiffuse));
        gl.uniform4fv(mspecLoc, NativeFloat32Array.from(jadeSpecular));
        gl.uniform1f(mshinyLoc, jadeShininess);
        break;
      case GlMaterial.pearl:
        gl.uniform4fv(mambLoc, NativeFloat32Array.from(pearlAmbient));
        gl.uniform4fv(mdiffLoc, NativeFloat32Array.from(pearlDiffuse));
        gl.uniform4fv(mspecLoc, NativeFloat32Array.from(pearlSpecular));
        gl.uniform1f(mshinyLoc, pearlShininess);
        break;
    }
  }

  // ***************************************************************
  // OpenGL：游戏
  // ***************************************************************
  //sphere.Sphere mySphere = sphere.Sphere();

  // ***************************************************************
  // OpenGL：渲染
  // ***************************************************************
  int t = DateTime.now().millisecondsSinceEpoch;
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
    installLights();
    renderScene();

    // 上屏
    gl.finish();
    if (!kIsWeb) {
      flutterGlPlugin.updateTexture(sourceTexture);
    }
  }

  // ***************************************************************
  // 游戏循环
  // ***************************************************************
  GameMode _gameMode = GameMode.pre;
  var lastTime = 0;
  gameLoop() {
    var currentTime = DateTime.now().millisecondsSinceEpoch;
    var dt = currentTime - lastTime;
    lastTime = currentTime;

    if (_gameMode == GameMode.pre) {
      // 设定球体初始位置
      var curr = 0;
      var rMat = vm.Matrix4.identity();
      rMat.rotate(cameraFront.cross(cameraUp), vm.radians(-35.0));
      var tmp = vm.Vector3.copy(cameraFront);
      tmp.scale(5);
      _sphere.instancePosition[curr] = cameraPos + rMat.transform3(tmp);
      _sphere.instanceScale[curr] = 1.8;
    } else if (_gameMode == GameMode.act) {
      var curr = 0;
      // 物体运动
      for (final model in _models) {
        //model.update(dt, gravity);
      }
      _sphere.update(dt, gravity);

      // 碰撞检测
      for (var i = 0; i < _models.length; i++) {
        for (var j = 0; j < _models[i].instancePosition.length; j++) {
          var curr = 0;
          if (_sphere.collision(curr, _models[i], j)) {
            _models[i].instanceFlag[j] = 1;
            _gameMode = GameMode.over;
          } else {
            _models[i].instanceFlag[j] = 0;
          }
        }
      }
    }
  }

  animate() {
    render();
    gameLoop();

    Future.delayed(const Duration(milliseconds: 20), () {
      animate();
    });
  }

  // ***************************************************************
  // 外围设备
  // ***************************************************************
  // 陀螺仪
  bool _listenGyroscope = false;
  GyroscopeEvent? _gyroscopeEvent;
  int? _gyroscopeLastInterval;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  DateTime? _gyroscopeUpdateTime;
  static const Duration _ignoreDuration = Duration(milliseconds: 20);
  Duration sensorInterval = SensorInterval.gameInterval;
  double _gyroscopeSensitivity = 0.5;

  _setupGyroscope() {
    _streamSubscriptions.add(
      gyroscopeEventStream(samplingPeriod: sensorInterval).listen(
        (GyroscopeEvent event) {
          final now = event.timestamp;
          setState(() {
            _gyroscopeEvent = event;
            if (_gyroscopeUpdateTime != null) {
              final interval = now.difference(_gyroscopeUpdateTime!);
              if (interval > _ignoreDuration) {
                _gyroscopeLastInterval = interval.inMilliseconds;
              }
            }
          });
          _gyroscopeUpdateTime = now;

          if (_gyroscopeEvent != null && _listenGyroscope) {
            final dt = _gyroscopeLastInterval != null
                ? _gyroscopeLastInterval! / 1000.0
                : 0.033; // 默认 33ms

            // 旋转矩阵
            final rotationMatrix = vm.Matrix4.rotationX(
                    _gyroscopeEvent!.x * dt * _gyroscopeSensitivity) *
                vm.Matrix4.rotationY(
                    _gyroscopeEvent!.y * dt * _gyroscopeSensitivity) *
                vm.Matrix4.rotationZ(
                    _gyroscopeEvent!.z * dt * _gyroscopeSensitivity);

            // 更新相机方向
            cameraFront = rotationMatrix.transform3(cameraFront);
            cameraFront.normalize();
            cameraUp = rotationMatrix.transform3(cameraUp);
            cameraUp.normalize();
          }
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support Gyroscope Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );
  }

  // 相机
  CameraController? cameraController;
  Throttler cameraThrottler = Throttler(milliSeconds: 33); // 图像流限速器
  NativeUint8Array? cameraData; // 背景纹理数据
  double cameraFov = 45.0;
  double cameraVelocity = 0.1;
  vm.Vector3 cameraPos = vm.Vector3(0.0, 0.0, 12.0),
      cameraFront = vm.Vector3(0.0, 0.0, -1.0),
      cameraUp = vm.Vector3(0.0, 1.0, 0.0);
  late vm.Matrix4 pMat;
  late vm.Matrix4 vMat =
      vm.makeViewMatrix(cameraPos, cameraPos + cameraFront, cameraUp);

  Future<void> _setupCameraController() async {
    WidgetsFlutterBinding.ensureInitialized();
    List<CameraDescription> cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      final cameraDescription = cameras
          .where(
            (element) => element.lensDirection == CameraLensDirection.back,
          )
          .first;
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

  void streamCameraImage() {
    if (cameraController?.value.isStreamingImages == false) {
      cameraController?.startImageStream((image) async {
        cameraThrottler.run(() async {
          imglib.Image processedImage = convertCameraImage(image);
          int x = ((processedImage.width - (width * dpr).toInt()) ~/ 2);
          int y = ((processedImage.height - (height * dpr).toInt()) ~/ 2);
          processedImage = imglib.copyCrop(processedImage,
              x: x,
              y: y,
              width: (width * dpr).toInt(),
              height: (height * dpr).toInt());

          cameraData = NativeUint8Array.from(processedImage.toUint8List());

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

  // 外围设备仅在应用启动时初始化一次
  void _requestPermission() async {
    if (Platform.isAndroid && Platform.isIOS) {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        await Permission.camera.request();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _requestPermission();

    _setupCameraController();
    _setupGyroscope();
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }
}
