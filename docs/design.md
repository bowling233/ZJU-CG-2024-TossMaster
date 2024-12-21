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

### 移动端渲染机制

### 模型

### 材质与纹理

### 几何变换

### 光照模型

## 高级要求部分

### 漫游时碰撞检测

### 移动端跨平台实现

### 增强现实应用

## 项目难点

### AR 实现

对于 AR，我们最初计划使用 OpenCV ArUco Marker 标记识别获得相机姿态，但是遇到了下列问题：

- OpenCV VideoCapture 在安卓上仅能输出灰度图像，原因见 [OpenCV](https://github.com/rainyl/opencv_dart/issues/159#issuecomment-2238065384)。
- `opencv_dart` 缺少关键的相机姿态估计函数 `solvePnP` 和 `estimatePoseSingleMarkers` 的绑定。
- OpenCV 相机姿态解析需要先对相机进行大量的标定（Camera Calibration），这涉及计算机视觉相关的内容，我们无法在短时间内完成。

这些问题非常关键，导致我们放弃了 OpenCV。

接下来考虑现有 AR 框架。AR 框架在平台之间分裂，如安卓有 ARCore，iOS 有 ARKit。引入 AR 框架将导致平台依赖，也加重了负担，因为我们只希望从单张图片中获取相机姿态。如果使用 AR 框架，一般需要启动一个 AR 会话，导致相机的实时捕捉。

最后我们自行实现平面识别和相机姿态估计算法。

## 参考文献

- 下面的文献帮助我们学习了如何使用 Flutter Camera 库的相机提供图片流，并进行适当的编码处理供 OpenGL 渲染。
    - [theamorn/flutter-stream-image](https://github.com/theamorn/flutter-stream-image)：
    - [[Flutter] 用相機畫面一小部分做辨識。這篇文章源自於我在工作上第一次選用 Flutter… | by Claire Liu | Flutter Taipei | Medium](https://medium.com/flutter-taipei/flutter-%E5%B0%87%E7%9B%B8%E6%A9%9F%E7%95%AB%E9%9D%A2%E4%B8%80%E5%B0%8F%E9%83%A8%E5%88%86%E5%81%9A%E8%BE%A8%E8%AD%98-8247e9372c52)
    - [image_converter.dart](https://gist.github.com/Alby-o/fe87e35bc21d534c8220aed7df028e03)
- 下面的文献帮助我们实现了 AR 算法：
    - [Nocami/PythonComputerVision-5-AR: 借助 pygame 和 openGL 在平面内实现简单的 AR 例子](https://github.com/Nocami/PythonComputerVision-5-AR)
