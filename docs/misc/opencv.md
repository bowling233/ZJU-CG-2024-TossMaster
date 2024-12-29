# OpenCV

可参考的例子：

- [AshishChouhan85/AR-USING-OPENGL](https://github.com/AshishChouhan85/AR-USING-OPENGL)：OpenGL + OpenCV ArUco Marker 的增强现实 Python Demo。

在目前看到的几个项目中，OpenCV 识别各类 Marker 的简易实现可能会出现抖动，导致效果不佳。需要考虑如何在稳定矩阵的同时保持实时性。

## 修改 opencv_dart demo

- 将 Videocapture 输入输出从文件分别替换为摄像头和图像缓冲区。
- 添加相机权限。需要使用 flutter permission_handler 插件，在 initState 中请求权限。

## OpenCV 与 OpenGL 的交互问题

后来因为 OpenCV VideoCapture 仅能输出灰度图像而放弃。

### 使用 camera 获得图像流

目前代码中，在 ImageStream 内执行图像格式转换，安卓上格式为 yuv420。转换函数：

- 首先构造空白图片
- 然后抽取 yuv420 数据
- 最终对空白图片中的每个像素 `wh`，设置其 RGB 值。

所得的 image，我们直接抽取 getBytes 得到 OpenGL 所需的 RGB 数据。

处理图片大小时还遇到了 Device Pixel Ratio 的问题，暂时不知道需要做什么。反正 FBO 是按物理像素乘 DPR 建立的。https://stackoverflow.com/questions/8785643/what-exactly-is-device-pixel-ratio
