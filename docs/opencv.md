# OpenCV

可参考的例子：

- [AshishChouhan85/AR-USING-OPENGL](https://github.com/AshishChouhan85/AR-USING-OPENGL)：OpenGL + OpenCV ArUco Marker 的增强现实 Python Demo。

在目前看到的几个项目中，OpenCV 识别各类 Marker 的简易实现可能会出现抖动，导致效果不佳。需要考虑如何在稳定矩阵的同时保持实时性。

## 修改 opencv_dart demo

- 将 Videocapture 输入输出从文件分别替换为摄像头和图像缓冲区。
- 添加相机权限。需要使用 flutter permission_handler 插件，在 initState 中请求权限。

## OpenCV 与 OpenGL 的交互问题

### 图像格式

OpenCV 中图像存储为 Mat，需要转换为 OpenGL 合适的纹理对象。幸运的是 opencv_dart 提供了比较完善的示例，其中涉及视频流图像转换：

```dart

Uint8List? _wroteFrame;
_wroteFrame == null
                ? const Placeholder()
                : Image.memory(
                    _wroteFrame!,
                    width: 300,
                  ),
```

这里 `_wroteFrame` 正是要传入 OpenGL 纹理的数据格式，看看它是怎么转换的：

```dart
final vc1 = cv.VideoCapture.fromFile(dst!);
final (s, f) = await vc1.readAsync();
vc1.dispose();

if (s) {
        final (s1, bytes) = await cv.imencodeAsync(".png", f);
        f.dispose();

        if (s1) {
                setState(() {
                        _wroteFrame = bytes;
                });
        }
}
```

后来因为 OpenCV VideoCapture 仅能输出灰度图像而放弃。

### 使用 camera 获得图像流

- 参考 [](https://medium.com/kbtg-life/real-time-machine-learning-with-flutter-camera-bbcf1b5c3193) 获得图像流
- 参考 [](https://medium.com/flutter-taipei/flutter-%E5%B0%87%E7%9B%B8%E6%A9%9F%E7%95%AB%E9%9D%A2%E4%B8%80%E5%B0%8F%E9%83%A8%E5%88%86%E5%81%9A%E8%BE%A8%E8%AD%98-8247e9372c52) 对图像进行裁切处理
- 上面两个参考资料都引用了 [](https://gist.github.com/Alby-o/fe87e35bc21d534c8220aed7df028e03) 的转换代码。

目前代码中，在 ImageStream 内执行图像格式转换，安卓上格式为 yuv420。转换函数：

- 首先构造空白图片
- 然后抽取 yuv420 数据
- 最终对空白图片中的每个像素 `wh`，设置其 RGB 值。

所得的 image，我们直接抽取 getBytes 得到 OpenGL 所需的 RGB 数据。

处理图片大小时还遇到了 Device Pixel Ratio 的问题，暂时不知道需要做什么。反正 FBO 是按物理像素乘 DPR 建立的。https://stackoverflow.com/questions/8785643/what-exactly-is-device-pixel-ratio
