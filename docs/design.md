# Toss Master 项目设计文档

作者：

- 朱宝林 3220106026
- 杨琳玥

## 目标与说明

本项目构思时主要考虑高级要求中的两条内容：

- （8 分）不依赖现有引擎，采用 iOS/Android 平台实现。
- （7 分）与增强现实应用结合。

项目分工：

- 杨琳玥：负责碰撞检测，主循环设计。
- 朱宝林：负责将代码迁移到 Flutter 框架，处理用户交互和 AR。

## 整体架构

## OpenGL 部分

### 模型

项目具备基本的体素建模表达能力，且能够导入 OBJ 格式的三维模型。

在项目内，所有模型存储在模型库中。模型库中的每个模型的数据结构具有：

- 模型的基本数据：顶点、法向量、纹理坐标、纹理图片。
- 模型的实例数据：对应场景中的每个模型实例，包括位置向量、旋转四元数、缩放数值、特殊标记（标记高量选中等）。

渲染时，遍历模型库，绘制每个模型的不同实例。通过实例化渲染，可以减少重复绘制相同模型的开销。

```dart
for (final model in models) {
    model.render(gl);
}

void render(gl) {
  // 模型数据
  gl.bindVertexArray(vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo[0]);
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo[1]);
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo[2]);
  gl.activeTexture(gl.TEXTURE0);
  gl.bindTexture(gl.TEXTURE_2D, texture);
  // 实例数据
  if (instancePosition.isEmpty) return;
  List<double> mMatrix = [];
  for (var i = 0; i < instancePosition.length; i++) {
      var modelMatrix = Matrix4.compose(instancePosition[i],
          instanceRotation[i], Vector3.all(instanceScale[i]));
      mMatrix.addAll(modelMatrix.storage);
  }
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo[3]);
  gl.bufferData(gl.ARRAY_BUFFER, mMatrix.length * Float32List.bytesPerElement,
      Float32List.fromList(mMatrix), gl.STATIC_DRAW);
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo[4]);
  gl.bufferData(
      gl.ARRAY_BUFFER,
      instanceFlag.length * Int32List.bytesPerElement,
      Int32List.fromList(instanceFlag),
      gl.STATIC_DRAW);
  // 实例化绘制
  gl.drawArraysInstanced(
      gl.TRIANGLES, 0, numVertices, instancePosition.length);
}
```

### 几何变换

项目支持用户通过触控手势对模型进行平移、旋转、缩放等基本几何变换。

对于我们渲染的 OpenGL Native Texture 组件，我们将其包装在 Flutter 框架提供的 `GestureDetector` 中，以便捕获用户的触控手势。我们通过该组件的回调函数对模型进行变换：

```dart
onScaleUpdate: (ScaleUpdateDetails event) => setState(() {
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

  _models[_selectedModelIndex!].transform(
      _selectedModelInstanceIndex!,
      positionDelta,
      rotationDelta,
      scaleDiff);
}),
```

### 光照模型

项目实现了 Blinn-Phong 着色的 ADS 光照模型，并实现了基本的光源控制。

本项目有两个光源：

- 全局光：没有方向，仅有 A（环境光）分量，对每个像素具有相同的光照。
- 定向光（远距离光）：具有方向和 A（环境光）、D（漫反射光）、S（镜面光）三个反射分量。

光照作为统一变量传递给着色器。与 Phong 着色相比，Blinn-Phong 着色节省了大量的性能损耗，适合移动端的渲染。在顶点着色器中，对法向量进行差值，随后在片段着色器中计算 ADS 分量：

```glsl
// normalize the light, normal, and view vectors:
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
```

用户能够通过「光照」控制界面的控件调节全局光的强度，定向光的位置、颜色、强度等参数。下面以光源位置调节为例，其采用圆形滑块控件，控件的 `onValueChanged` 回调函数中更新光源的位置：

```dart
SfRadialGauge(
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
)
```

### 材质与纹理

项目具备基本的材质和纹理的显示和编辑能力。

在导入模型时，可以选择性地导入纹理图片，存储在上节所述的模型库的每个模型中：

```dart
factory ImportedModel(
    gl, String objData, Uint8List? texData, Uint8List? gifData) {
  // ...
  // 纹理数据
  int? texture;
  if (texData != null) {
    log('ImportedModel.assets() texData');
    Image texImg = decodeImage(texData)!.convert(numChannels: 4);
    texImg = flipVertical(texImg);
    var textureData = NativeUint8Array.from(texImg.toUint8List());
    texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texImg.width, texImg.height, 0,
        gl.RGBA, gl.UNSIGNED_BYTE, textureData);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  }
  // ...
}
```

对于所有不具备纹理的模型，我们提供默认的材质。材质按照 ADS 光照模型对材质进行着色：

```dart
const List<double> goldAmbient = [0.2473, 0.1995, 0.0745, 1.0];
const List<double> goldDiffuse = [0.7516, 0.6065, 0.2265, 1.0];
const List<double> goldSpecular = [0.6283, 0.5559, 0.3661, 1.0];
const double goldShininess = 51.2;
```

材质所使用的着色器：

```glsl
// material
ambient = ((globalAmbient * material.ambient) + (light.ambient * material.ambient)).xyz;
diffuse = light.diffuse.xyz * material.diffuse.xyz * max(cosTheta,0.0);
specular = light.specular.xyz * material.specular.xyz * pow(max(cosPhi,0.0), material.shininess*3.0);
fragColor = vec4((ambient + diffuse + specular), 1.0);
```

我们也测试了结合纹理与光照，但是发现最终效果不好，参数比较难调节，一般情况下都造成模型过暗。所以我们决定分开处理，一个模型要么使用纹理，要么使用材质。

## 高级要求部分

### 漫游时碰撞检测

我们的游戏状态机如下：

TODO：状态机图

该游戏循环和渲染循环在同一个异步线程中执行，因此能够实现实时的碰撞检测。

### 移动端跨平台实现

项目

在移动端，我们不再具有 PC 端完善的基础设施，缺少 SOIL2、GLFW、GLM 等库，因此我们需要自行实现这些功能。

首先要考虑的就是帧缓冲区。在 PC 上，GLFW 帮助我们完成了窗口和帧缓冲区的创建。但是在移动端，我们需要自行创建，`flutter_gl` 仅仅提供将离线渲染好的纹理绘制到屏幕上的功能。因此我们先创建离屏渲染用的 FrameBuffer：

```dart
setupDefaultFBO() {
  final gl = flutterGlPlugin.gl;
  int glWidth = (width * dpr).toInt();
  int glHeight = (height * dpr).toInt();

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
```

完成离屏渲染 FrameBuffer 绑定后，后续的渲染操作都是在这个 FrameBuffer 上进行的，按照 PC 端的渲染流程执行即可。渲染完成后，调用 `flutter_gl` 提供的函数，将该 FrameBuffer 的颜色纹理传递到原生纹理组件，从而实现渲染到屏幕。

```dart
gl.finish();
if (!kIsWeb) {
  flutterGlPlugin.updateTexture(defaultFboTex);
}
```

### 增强现实应用

## 项目难点

### AR 实现

对于 AR，我们最初计划使用 OpenCV ArUco Marker 标记识别获得相机姿态，但是遇到了下列问题：

- OpenCV VideoCapture 在安卓上仅能输出灰度图像，原因见 [OpenCV](https://github.com/rainyl/opencv_dart/issues/159#issuecomment-2238065384)。
- `opencv_dart` 缺少关键的相机姿态估计函数 `solvePnP` 和 `estimatePoseSingleMarkers` 的绑定。
- OpenCV 相机姿态解析需要先对相机进行大量的标定（Camera Calibration），这涉及计算机视觉相关的内容，我们无法在短时间内完成。

这些问题非常关键，导致我们放弃了 OpenCV。

接下来考虑现有 AR 框架。AR 框架在平台之间分裂，如安卓有 ARCore，iOS 有 ARKit。引入 AR 框架将导致平台依赖，也加重了负担，因为我们只希望从单张图片中获取相机姿态。如果使用 AR 框架，一般需要启动一个 AR 会话，导致相机的实时捕捉。我们其实也做了一些尝试，但是没有成功：

- `ar_flutter_plugin` 能够支持安卓和 iOS，但已经 2 年无人维护，产生了一堆依赖问题，短时间内我们无法解决。
- `arcore_flutter_plugin` 缺少相机参数接口。
- `arkit_plugin` 具有接口，但开发人员缺少 iOS 设备，无法测试。

自行实现平面识别和相机姿态估计算法已经远远超出了课程的范围，我们最终决定放弃 AR 部分。

## 参考文献

- 下面的文献帮助我们学习了如何使用 Flutter Camera 库的相机提供图片流，并进行适当的编码处理供 OpenGL 渲染。
    - [theamorn/flutter-stream-image](https://github.com/theamorn/flutter-stream-image)：
    - [[Flutter] 用相機畫面一小部分做辨識。這篇文章源自於我在工作上第一次選用 Flutter… | by Claire Liu | Flutter Taipei | Medium](https://medium.com/flutter-taipei/flutter-%E5%B0%87%E7%9B%B8%E6%A9%9F%E7%95%AB%E9%9D%A2%E4%B8%80%E5%B0%8F%E9%83%A8%E5%88%86%E5%81%9A%E8%BE%A8%E8%AD%98-8247e9372c52)
    - [image_converter.dart](https://gist.github.com/Alby-o/fe87e35bc21d534c8220aed7df028e03)
