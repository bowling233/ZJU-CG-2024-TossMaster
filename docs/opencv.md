# OpenCV

可参考的例子：

- [AshishChouhan85/AR-USING-OPENGL](https://github.com/AshishChouhan85/AR-USING-OPENGL)：OpenGL + OpenCV ArUco Marker 的增强现实 Python Demo。

在目前看到的几个项目中，OpenCV 识别各类 Marker 的简易实现可能会出现抖动，导致效果不佳。需要考虑如何在稳定矩阵的同时保持实时性。

## 修改 opencv_dart demo

- 将 Videocapture 输入输出从文件分别替换为摄像头和图像缓冲区。
- 添加相机权限。需要使用 flutter permission_handler 插件，在 initState 中请求权限。
