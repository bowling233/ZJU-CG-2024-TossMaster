---
marp: true
---

TossMaster
===

##### 基于 Flutter 框架、OpenGL ES 3.0 渲染的 3D 跨平台 AR 投掷游戏

###### by 朱宝林 杨琳玥

---

# 一、项目内容

---

# 二、Demo 展示

---

# 三、心得与体会

##### 充满着荆棘与坎坷的跨平台开发之路

###### 强烈不建议无移动端开发经验的同学尝试基于 OpenGL 的跨平台开发

---

## 3.1 缺少基础设施的 Flutter

![bg right:45% contain](presentation.assets/flutter_no_infra.png)

极少有人在跨平台框架中直接使用 OpenGL 这类底层库进行开发。

<style scoped>
table {
 font-size: 20px;
}
blockquote {
 font-size: 18px;
}
</style>

| 项目 | 状态 |
| --- | --- |
| [google/dart-gl](https://github.com/google/dart-gl)<br/>Dart 原生 GLES2 扩展 | 2022 年停止维护 |
| [alnitak/flutter_opengl](https://github.com/alnitak/flutter_opengl)<br/>GLSL 玩具罢了😢（[ShaderToy.com](https://www.shadertoy.com/)） | 2022 年 |
| [wasabia/flutter_gl](https://github.com/wasabia/flutter_gl)<br/>通过 `dart:ffi` 绑定到 C 接口 | 2022 年 |

> Star 数均不超过 200，![width:50px](https://user-images.githubusercontent.com/6718144/101553774-3bc7b000-39ad-11eb-8a6a-de2daa31bd64.png)Flame 它不香吗？

---

### `wasabia/flutter_gl` 的绘制方式

![bg right contain](presentation.assets/flutter_gl.svg)

---

## 3.2 百花齐放的图像编码

从 `startImageStream((image) async {})` 获得的 `image` 可能为：

- iOS：BGRA8888
- Android：YUV420

启动相机串流后，OpenGL 和 Flutter Widget 帧率均显著下降。

![bg right:40% contain](presentation.assets/profile.png)

<!-- _footer: "*Reference [Real-time Machine Learning with Flutter Camera | KBTG LifeMohamed Nohassi](https://medium.com/kbtg-life/real-time-machine-learning-with-flutter-camera-bbcf1b5c3193)*" -->
---

## 3.3 Dart 是一门函数式语言

Dart 是一款由 Google 开发的函数式编程语言，你将在 Flutter 框架中探索无状态和数据的不可变性......

![bg right:30% contain](presentation.assets/video-lag.gif)


![](https://docs.flutter.dev/assets/images/docs/development/data-and-backend/state-mgmt/ui-equals-function-of-state.png)

> When the state of your app changes (for example, the user flips a switch in the settings screen), you change the state, and that triggers a **redraw of the user interface**.

---

### 拒绝重绘！

将所有状态存储在一个 Widget 中，状态变更在 Widget 内部处理。

---

## 3.4 何尝不算一种 AR？

- 最初计划：借助 OpenCV 的 ArUco Marker 实现，然而
  - `opencv_dart` 缺少关键的相机姿态估计函数 `solvePnP` 和 `estimatePoseSingleMarkers` 的绑定。
  - OpenCV 相机姿态解析需要先对相机进行大量的标定（Camera Calibration），涉及计算机视觉相关的内容，难以在项目时间内完成。
- 求助 AR 框架：
  - 平台分裂：安卓 ARCore，iOS ARKit
    - `arcore_flutter_plugin` 缺少相机参数接口。
    - `arkit_plugin` 具有接口，但开发人员缺少 iOS 设备，无法测试。
  - `ar_flutter_plugin` 实现了两者的跨平台支持，但年久失修，有严重的依赖问题。
- 手搓 PnP 或 RANSAC 算法？超出课程范围。

---

## 换个思路：传感器

移动端设备具有加速度计、陀螺仪，可以感知设备的运动状态。

- 加速度计：离散采样难以获得准确的位移信息。使用 $\mathrm{d}x = v_x \cdot \mathrm{d}t + \frac{1}{2} a_x \cdot \mathrm{d}t^2$ 计算，转动时出现明显漂移，走半天却没有位移变化（无加速度）。
- 陀螺仪：角速度信息 $\mathrm{rad/s}$，可积分得到旋转角度，实测表现良好。旁轴旋转时产生偏移，暂未探究原因。

---

## 3.5 鸿蒙与安卓亦有不同☹️

<style scoped>
pre {
  background-color: transparent;
}
</style>

```text
OpenGL Error: 1282
Error compiling shader:
S0059: 'binding' qualifier is not allowed in language version 300 es
```

![](presentation.assets/glsl_diff.png)

<!-- _footer: "*Reference [OpenGL ES Shading Language Version 3.00](https://www.khronos.org/registry/OpenGL/specs/es/3.0/GLSL_ES_Specification_3.00.pdf)*，OpenGL ES 3.20 得到支持" -->

---

## 寸土寸金的移动端存储

```txt
S0032: no default precision defined for variable 'varyingNormal'
L0001 The fragment matrix variable proj_matrix does not match the vertex variable proj_matrix.
  The matrix stride does not match.
```

所有数据都需要

---

# Features

- :memo: **Write slide deck with plain Markdown** (CommonMark)
- :factory: Built on [Marpit framework][marpit]: A brand-new skinny framework for creating slide deck
- :gear: [Marp Core][marp-core]: Easy to start using the core engine and built-in themes via npm
- :tv: [Marp CLI][marp-cli]: Convert Markdown into HTML, PDF, PPTX, and images
- :vs: [Marp for VS Code][marp-vscode]: Live-preview your deck while editting
- and more...

---

# How to write slides?

Split pages by horizontal ruler (e.g. `---`). It's very simple.

```markdown
# Slide 1

foobar

---

# Slide 2

foobar
```

---

# Directives

Marp has extended syntax called **"Directives"** to support creating beautiful slides.

Insert front-matter to the top of Markdown:

```
---
theme: default
---
```

or HTML comment to anywhere:

```html
<!-- theme: default -->
```

<https://marpit.marp.app/directives>

---

## [Global directives](https://marpit.marp.app/directives?id=global-directives)

- `theme`: Choose theme
- `size`: Choose slide size from `16:9` and `4:3` *(except Marpit framework)*
- [`headingDivider`](https://marpit.marp.app/directives?id=heading-divider): Instruct to divide slide pages at before of specified heading levels

```
---
theme: gaia
size: 4:3
---

# Content
```

> Marp can use [built-in themes in Marp Core](https://github.com/marp-team/marp-core/tree/master/themes#readme): `default`, `gaia`, and `uncover`.

---

## [Local directives](https://marpit.marp.app/directives?id=local-directives)

These are the setting value per slide pages.

- `paginate`: Show pagination by set `true`
- `header`: Specify the contents for header
- `footer`: Specify the contents for footer
- `class`: Set HTML class for current slide
- `color`: Set text color
- `backgroundColor`: Set background color

---

### Spot directives

Local directives would apply to **defined page and following pages**.

They can apply to single page by using underscore prefix such as `_class`.

![bg right 95%](https://marpit.marp.app/assets/directives.png)

---

### Example

This page is using invert color scheme [defined in Marp built-in theme](https://github.com/marp-team/marp-core/tree/master/themes#readme).

<!-- _class: invert -->

```html
<!-- _class: invert -->
```

---

# [Image syntax](https://marpit.marp.app/image-syntax)

You can resize image size and apply filters through keywords: `width` (`w`), `height` (`h`), and filter CSS keywords.

```markdown
![width:100px height:100px](image.png)
```

```markdown
![blur sepia:50%](filters.png)
```

Please refer [resizing image syntax](https://marpit.marp.app/image-syntax?id=resizing-image) and [a list of CSS filters](https://marpit.marp.app/image-syntax?id=image-filters).

![w:100px h:100px](https://avatars1.githubusercontent.com/u/20685754?v=4) ![w:100 h:100 blur sepia:50%](https://avatars1.githubusercontent.com/u/20685754?v=4)

---

# [Background image](https://marpit.marp.app/image-syntax?id=slide-backgrounds)

You can set background image for a slide by using `bg` keyword.

```markdown
![bg opacity](https://yhatt-marp-cli-example.netlify.com/assets/gradient.jpg)
```

![bg opacity](https://yhatt-marp-cli-example.netlify.com/assets/gradient.jpg)

---

## Multiple backgrounds ([Marpit's advanced backgrounds](https://marpit.marp.app/image-syntax?id=advanced-backgrounds))

Marp can use multiple background images.

```markdown
![bg blur:3px](https://fakeimg.pl/800x600/fff/ccc/?text=A)
![bg blur:3px](https://fakeimg.pl/800x600/eee/ccc/?text=B)
![bg blur:3px](https://fakeimg.pl/800x600/ddd/ccc/?text=C)
```

Also can change alignment direction by including `vertical` keyword.

![bg blur:3px](https://fakeimg.pl/800x600/fff/ccc/?text=A)
![bg blur:3px](https://fakeimg.pl/800x600/eee/ccc/?text=B)
![bg blur:3px](https://fakeimg.pl/800x600/ddd/ccc/?text=C)

---

## [Split background](https://marpit.marp.app/image-syntax?id=split-backgrounds)

Marp can use [Deckset](https://docs.deckset.com/English.lproj/Media/01-background-images.html#split-slides) style split background(s).

Make a space for background by `bg` + `left` / `right` keywords.

```markdown
![bg right](image.jpg)
```

![bg right](https://images.unsplash.com/photo-1568488789544-e37edf90eb67?crop=entropy&cs=tinysrgb&fit=crop&fm=jpg&h=720&ixlib=rb-1.2.1&q=80&w=640)

<!-- _footer: "*Photo by [Mohamed Nohassi](https://unsplash.com/@coopery?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)*" -->

---

## [Fragmented list](https://marpit.marp.app/fragmented-list)

Marp will parse a list with asterisk marker as the fragmented list for appearing contents one by one. (***Only for exported HTML** by [Marp CLI][marp-cli] / [Marp for VS Code][marp-vscode]*)

```markdown
# Bullet list

- One
- Two
- Three

---

# Fragmented list

* One
* Two
* Three
```

---

## Math typesetting (only for [Marp Core][marp-core])

[KaTeX](https://katex.org/) math typesetting such as $ax^2+bc+c$ can use with [Pandoc's math syntax](https://pandoc.org/MANUAL.html#math).

$$I_{xx}=\int\int_Ry^2f(x,y)\cdot{}dydx$$

```tex
$ax^2+bc+c$
```

```tex
$$I_{xx}=\int\int_Ry^2f(x,y)\cdot{}dydx$$
```

---

## Auto-scaling (only for [Marp Core][marp-core])

*Several built-in themes* are supported auto-scaling for code blocks and math typesettings.

```text
Too long code block will be scaled-down automatically. ------------>
```

```text
Too long code block will be scaled-down automatically. ------------------------>
```

```text
Too long code block will be scaled-down automatically. ------------------------------------------------>
```

---

##### <!--fit--> Auto-fitting header (only for [Marp Core][marp-core])

##### <!--fit--> is available by annotating `<!--fit-->` in headings

<br />

```html
## <!--fit--> Auto-fitting header (only for Marp Core)
```

---

## [Theme CSS](https://marpit.marp.app/theme-css)

Marp uses `<section>` as the container of each slide. And others are same as styling for plain Markdown. The customized theme can use in [Marp CLI][marp-cli] and [Marp for VS Code][marp-vscode].

```css
/* @theme your-theme */

@import 'default';

section {
  /* Specify slide size */
  width: 960px;
  height: 720px;
}

h1 {
  font-size: 30px;
  color: #c33;
}
```

---

## [Tweak style in Markdown](https://marpit.marp.app/theme-css?id=tweak-style-through-markdown)

`<style>` tag in Markdown will work in the context of theme CSS.

```markdown
---
theme: default
---

<style>
section {
  background: yellow;
}
</style>

Re-painted yellow background, ha-ha.
```

> You can also add custom styling by class like `section.custom-class { ... }`.
> Apply style through `<!-- _class: custom-class -->`.

---

## [Scoped style](https://marpit.marp.app/theme-css?id=scoped-style)

If you want one-shot styling for current page, you can use `<style scoped>`.

```markdown
<style scoped>
a {
  color: green;
}
</style>

![Green link!](https://marp.app/)
```

<style scoped>
a { color: green; }
</style>

---

# Enjoy writing slides! :v: <!--fit-->

##### ![w:1em h:1em](https://avatars1.githubusercontent.com/u/20685754?v=4)  Marp: Markdown presentation ecosystem — <https://marp.app/>

###### by Marp Team ([@marp-team][marp-team])
