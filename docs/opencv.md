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
