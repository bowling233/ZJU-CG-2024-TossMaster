# Toss Master

浙江大学《计算机图形学》2024 年秋冬学期课程大作业。基于 Flutter 框架开发的，使用 OpenGL ES 3.0 渲染的 3D 跨平台 AR 投掷游戏。

，文档见 [`docs`](docs) 目录。

提交内容：

- 项目源代码：`src` 是 Flutter 项目的根目录，核心 Dart 代码位于 `src/lib`。
- 可执行文件：`release` 目录下包含 Android 平台和 iOS 平台的可执行文件。其中 iOS 平台因为 Apple 对中国区域开发者的限制，未能提供签名验证的可运行的 `.ipa` 程序，只提供了 `.app` 程序。Android 平台提供了可运行的 `.apk` 程序，安装可能需要开发者模式。
- 文档：`docs` 目录。其中：
    - `presentation.md` 和 `presentation.html` 为 Marp 构建的展示用 PPT。附件文件夹 `presentation.assets` 中包含了展示用的 demo GIF 图片。
    - `design.md` 和 `design.pdf` 为系统设计说明文档。
