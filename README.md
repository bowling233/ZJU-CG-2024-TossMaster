# Toss Master

## 整体架构

按照 Dart 语言函数式的特点，架构中所有组件都是无状态的函数（内部可以有一些临时的缓存，但每次构建还是要从上级拿）。

定义全局状态 `TossMasterState`，保存游戏场景中的状态，这些内容将被界面中的多个组件编辑：

- 相机（由 OpenGLScene 中 OpenCV 计算更新）
- 光照
- 模型库
- 场景中的物体（具有模型索引、自身的模型矩阵）

全局状态提供变更的所有接口，发生变更时通知组件重绘。

组件在合适的位置监听全局状态的变更。按照 ChangeNotifier 的设计，组件构建为 Consumer<State>，构建接受参数 (context, state, child)。其中 child 是子组件不受状态变更影响的部分。

Flutter 这样的组件架构意味着组件的重绘极为昂贵，我们不可能允许用户操作期间逐帧重绘组件，这会造成场景闪烁。重绘应该等待用户操作完成，先将用户更改传递到。

## OpenGLScene

本次作业的核心。我们来看渲染循环：

## 其他

### 关于 AR 部分

实话说，构思这个项目的时候就是冲着高级要求中的这两点去的：

- 8 分：不依赖现有引擎，采用 iOS/Android 平台实现。
- 7 分：与增强显示应用结合。

嗯，事实证明要拿到高级要求的分数确实不容。

- OpenCV：最初计划采用 ArUco Marker 进行姿态估计，但是因为以下原因放弃了：
  - `opencv_dart` 缺少最关键的姿态估计的 API `solvePnP` 的绑定。
  - OpenCV 姿态估计需要做相机校正（camera calibration），需要大量标定。
