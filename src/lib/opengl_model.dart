import 'dart:typed_data';
import 'dart:developer';
import 'package:flutter_gl/native-array/NativeArray.app.dart';
import 'package:vector_math/vector_math.dart';
import 'package:image/image.dart';

enum ImportedModelState { onBoard, inAir }

class ImportedModel {
  // 顶点数据
  final int numVertices;
  List<double> vertices;
  final int vao;
  final List<dynamic> vbo;
  // 纹理数据
  int? texture; // 如果为空，则使用材质
  Uint8List? texData;
  Uint8List? gifData;
  // 碰撞盒数据
  final Vector3 halfSize;
  final int boxVao;
  final List<dynamic> boxVbo;

  // 实例数据
  final List<Vector3> instancePosition = [];
  final List<Vector3> instanceVelocity = [];
  final List<Quaternion> instanceRotation = [];
  final List<double> instanceScale = [];
  final List<int> instanceFlag = [];
  final List<ImportedModelState> instanceState = [];
  final List<double> instanceMass = [];

  factory ImportedModel(
      gl, String objData, Uint8List? texData, Uint8List? gifData) {
    log('ImportedModel.assets()');
    // 顶点数据：解析 OBJ 文件
    final List<double> vertVals = [];
    final List<double> triangleVerts = [];
    final List<double> textureCoords = [];
    final List<double> stVals = [];
    final List<double> normals = [];
    final List<double> normVals = [];

    final lines = objData.split('\n');

    for (var line in lines) {
      if (line.startsWith('v ')) {
        final parts = line.substring(2).trim().split(RegExp(r'\s+'));
        vertVals.addAll(parts.map(double.parse));
      } else if (line.startsWith('vt')) {
        final parts = line.substring(3).trim().split(RegExp(r'\s+'));
        stVals.addAll(parts.map(double.parse));
      } else if (line.startsWith('vn')) {
        final parts = line.substring(3).trim().split(RegExp(r'\s+'));
        normVals.addAll(parts.map(double.parse));
      } else if (line.startsWith('f ')) {
        final parts = line.substring(2).trim().split(' ');
        for (var corner in parts) {
          final indices = corner.split('/');
          final vertRef = (int.parse(indices[0]) - 1) * 3;
          final tcRef = (int.parse(indices[1]) - 1) * 2;
          final normRef = (int.parse(indices[2]) - 1) * 3;

          triangleVerts.addAll([
            vertVals[vertRef],
            vertVals[vertRef + 1],
            vertVals[vertRef + 2],
          ]);

          textureCoords.addAll([
            stVals[tcRef],
            stVals[tcRef + 1],
          ]);

          normals.addAll([
            normVals[normRef],
            normVals[normRef + 1],
            normVals[normRef + 2],
          ]);
        }
      }
    }

    final numVertices = triangleVerts.length ~/ 3;

    // 包围盒计算
    List<double> xVals = [];
    List<double> yVals = [];
    List<double> zVals = [];

    for (var i = 0; i < triangleVerts.length; i += 3) {
      xVals.add(triangleVerts[i]);
      yVals.add(triangleVerts[i + 1]);
      zVals.add(triangleVerts[i + 2]);
    }

    xVals.sort();
    yVals.sort();
    zVals.sort();

    final halfSize = Vector3((xVals.last - xVals.first) / 2,
        (yVals.last - yVals.first) / 2, (zVals.last - zVals.first) / 2);

    final centerX = (xVals.last + xVals.first) / 2;
    final centerY = (yVals.last + yVals.first) / 2;
    final centerZ = (zVals.last + zVals.first) / 2;

    // 移动模型到中心
    for (var i = 0; i < triangleVerts.length; i += 3) {
      triangleVerts[i] -= centerX;
      triangleVerts[i + 1] -= centerY;
      triangleVerts[i + 2] -= centerZ;
    }

    // 包围盒的顶点数据，按 GL_LINES 绘制
    // 共 12 条边，每条边 2 个顶点，每个顶点 3 个坐标
    List<double> boxVerts = [
      halfSize.x, halfSize.y, halfSize.z, halfSize.x, halfSize.y,
      -halfSize.z, // 1
      halfSize.x, halfSize.y, -halfSize.z, halfSize.x, -halfSize.y,
      -halfSize.z, // 2
      halfSize.x, -halfSize.y, -halfSize.z, halfSize.x, -halfSize.y,
      halfSize.z, // 3
      halfSize.x, -halfSize.y, halfSize.z, halfSize.x, halfSize.y,
      halfSize.z, // 4
      -halfSize.x, halfSize.y, halfSize.z, -halfSize.x, halfSize.y,
      -halfSize.z, // 5
      -halfSize.x, halfSize.y, -halfSize.z, -halfSize.x, -halfSize.y,
      -halfSize.z, // 6
      -halfSize.x, -halfSize.y, -halfSize.z, -halfSize.x, -halfSize.y,
      halfSize.z, // 7
      -halfSize.x, -halfSize.y, halfSize.z, -halfSize.x, halfSize.y,
      halfSize.z, // 8
      halfSize.x, halfSize.y, halfSize.z, -halfSize.x, halfSize.y,
      halfSize.z, // 9
      halfSize.x, halfSize.y, -halfSize.z, -halfSize.x, halfSize.y,
      -halfSize.z, // 10
      halfSize.x, -halfSize.y, -halfSize.z, -halfSize.x, -halfSize.y,
      -halfSize.z, // 11
      halfSize.x, -halfSize.y, halfSize.z, -halfSize.x, -halfSize.y,
      halfSize.z, // 12
    ];

    // 顶点数据：载入 OpenGL
    final vao = gl.createVertexArray();
    gl.bindVertexArray(vao);

    final vbo = List.generate(5, (i) => gl.createBuffer());
    // 0. vertex 1. texture 2. normal 3. instanceMatrix (4) 7. instanceFlag

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[0]);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        triangleVerts.length * Float32List.bytesPerElement,
        Float32List.fromList(triangleVerts),
        gl.STATIC_DRAW);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(0);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[1]);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        textureCoords.length * Float32List.bytesPerElement,
        Float32List.fromList(textureCoords),
        gl.STATIC_DRAW);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(1);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[2]);
    gl.bufferData(gl.ARRAY_BUFFER, normals.length * Float32List.bytesPerElement,
        Float32List.fromList(normals), gl.STATIC_DRAW);
    gl.vertexAttribPointer(2, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(2);

    // 注意：实例数据在渲染时传入
    // 注意：matrix 特殊，vetexAttribPointer 大小最多为 4，需要用 Stride 来实现
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[3]);
    gl.vertexAttribPointer(
        3, 4, gl.FLOAT, false, 16 * Float32List.bytesPerElement, 0);
    gl.vertexAttribDivisor(3, 1);
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(4, 4, gl.FLOAT, false,
        16 * Float32List.bytesPerElement, 4 * Float32List.bytesPerElement);
    gl.vertexAttribDivisor(4, 1);
    gl.enableVertexAttribArray(4);
    gl.vertexAttribPointer(5, 4, gl.FLOAT, false,
        16 * Float32List.bytesPerElement, 8 * Float32List.bytesPerElement);
    gl.vertexAttribDivisor(5, 1);
    gl.enableVertexAttribArray(5);
    gl.vertexAttribPointer(6, 4, gl.FLOAT, false,
        16 * Float32List.bytesPerElement, 12 * Float32List.bytesPerElement);
    gl.vertexAttribDivisor(6, 1);
    gl.enableVertexAttribArray(6);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[4]);
    gl.vertexAttribPointer(7, 1, gl.INT, false, 0, 0);
    gl.vertexAttribDivisor(7, 1);
    gl.enableVertexAttribArray(7);

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

    final boxVao = gl.createVertexArray();
    gl.bindVertexArray(boxVao);

    final boxVbo = List.generate(5, (i) => gl.createBuffer());
    // 0. vertex 1. texture 2. normal 3. instanceMatrix (4) 7. instanceFlag

    gl.bindBuffer(gl.ARRAY_BUFFER, boxVbo[0]);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        boxVerts.length * Float32List.bytesPerElement,
        Float32List.fromList(boxVerts),
        gl.STATIC_DRAW);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(0);

    gl.bindBuffer(gl.ARRAY_BUFFER, boxVbo[1]);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        boxVerts.length * Float32List.bytesPerElement,
        Float32List.fromList(boxVerts),
        gl.STATIC_DRAW);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(1);

    gl.bindBuffer(gl.ARRAY_BUFFER, boxVbo[2]);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        boxVerts.length * Float32List.bytesPerElement,
        Float32List.fromList(boxVerts),
        gl.STATIC_DRAW);
    gl.vertexAttribPointer(2, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(2);

    // 注意：实例数据在渲染时传入
    // 注意：matrix 特殊，vetexAttribPointer 大小最多为 4，需要用 Stride 来实现
    gl.bindBuffer(gl.ARRAY_BUFFER, boxVbo[3]);
    gl.vertexAttribPointer(
        3, 4, gl.FLOAT, false, 16 * Float32List.bytesPerElement, 0);
    gl.vertexAttribDivisor(3, 1);
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(4, 4, gl.FLOAT, false,
        16 * Float32List.bytesPerElement, 4 * Float32List.bytesPerElement);
    gl.vertexAttribDivisor(4, 1);
    gl.enableVertexAttribArray(4);
    gl.vertexAttribPointer(5, 4, gl.FLOAT, false,
        16 * Float32List.bytesPerElement, 8 * Float32List.bytesPerElement);
    gl.vertexAttribDivisor(5, 1);
    gl.enableVertexAttribArray(5);
    gl.vertexAttribPointer(6, 4, gl.FLOAT, false,
        16 * Float32List.bytesPerElement, 12 * Float32List.bytesPerElement);
    gl.vertexAttribDivisor(6, 1);
    gl.enableVertexAttribArray(6);

    gl.bindBuffer(gl.ARRAY_BUFFER, boxVbo[4]);
    gl.vertexAttribPointer(7, 1, gl.INT, false, 0, 0);
    gl.vertexAttribDivisor(7, 1);
    gl.enableVertexAttribArray(7);

    // gif

    return ImportedModel._internal(
      numVertices,
      triangleVerts,
      vao,
      vbo,
      texture,
      texData,
      gifData,
      halfSize,
      boxVao,
      boxVbo,
    );
  }

  ImportedModel._internal(
      this.numVertices,
      this.vertices,
      this.vao,
      this.vbo,
      this.texture,
      this.texData,
      this.gifData,
      this.halfSize,
      this.boxVao,
      this.boxVbo);

  void instantiate() {
    instancePosition.add(Vector3(0, 0, -20));
    instanceVelocity.add(Vector3(0, 0, 0));
    instanceRotation.add(Quaternion.identity());
    instanceScale.add(1);
    instanceMass.add(1.0);
    instanceState.add(ImportedModelState.inAir);
    if (texture == null) {
      // 使用材质
      log('ImportedModel.instantiate() texture == null');
      instanceFlag.add(2);
    } else {
      // 使用纹理
      instanceFlag.add(0);
    }
  }

  // 渲染
  void render(gl) {
    if (instancePosition.isEmpty) return;
    // 模型数据
    gl.bindVertexArray(vao);
    if (texture == null) {
      gl.bindTexture(gl.TEXTURE_2D, 0);
    } else {
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, texture);
    }
    // 实例数据
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

  // 渲染包围盒
  void renderBox(gl) {
    if (instancePosition.isEmpty) return;
    // 包围盒数据
    gl.bindVertexArray(boxVao);
    // 实例数据
    List<double> mMatrix = [];
    for (var i = 0; i < instancePosition.length; i++) {
      var modelMatrix = Matrix4.compose(instancePosition[i],
          instanceRotation[i], Vector3.all(instanceScale[i]));
      mMatrix.addAll(modelMatrix.storage);
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, boxVbo[3]);
    gl.bufferData(gl.ARRAY_BUFFER, mMatrix.length * Float32List.bytesPerElement,
        Float32List.fromList(mMatrix), gl.STATIC_DRAW);
    List<int> boxFlag = List.filled(instanceFlag.length, 4);
    gl.bindBuffer(gl.ARRAY_BUFFER, boxVbo[4]);
    gl.bufferData(gl.ARRAY_BUFFER, boxFlag.length * Int32List.bytesPerElement,
        Int32List.fromList(boxFlag), gl.STATIC_DRAW);
    // 实例化绘制
    gl.lineWidth(2.0);
    gl.drawArraysInstanced(gl.LINES, 0, 24, instancePosition.length);
  }

  // 实例选择
  void select(int index) {
    log('[ImportedModel.select()] index: $index');
    instanceFlag[index] = 1;
  }

  void unSelect() {
    instanceFlag.fillRange(0, instanceFlag.length, texture == null ? 2 : 0);
  }

  // 模型选中测试
  ({int index, double t}) hitTest(
      Vector2 ndc, Vector3 cameraPos, Matrix4 vMat, Matrix4 pMat) {
    unSelect();
    pMat = Matrix4.copy(pMat);
    vMat = Matrix4.copy(vMat);
    // 反投影到裁剪空间
    var clipSpacePoint = Vector4(ndc.x, ndc.y, -1, 1);
    // 转换到视图空间
    var det = pMat.invert();
    if (det == 0) {
      log('[ImportedModel.select()] pMat is not invertible');
      return (index: -1, t: double.infinity);
    }
    Vector4 viewSpacePoint = pMat * clipSpacePoint;
    viewSpacePoint = viewSpacePoint / viewSpacePoint.w;
    // 转换到世界空间
    det = vMat.invert();
    if (det == 0) {
      log('[ImportedModel.select()] vMat is not invertible');
      return (index: -1, t: double.infinity);
    }
    var rayDirection = (vMat * viewSpacePoint.xyz - cameraPos).normalized();
    // 判定最近相交
    int selectedIdx = -1;
    double tMin = double.infinity;
    // 对场景中每个实例
    for (var idx = 0; idx < instancePosition.length; idx++) {
      var modelMatrix = Matrix4.compose(instancePosition[idx],
          instanceRotation[idx], Vector3.all(instanceScale[idx]));
      // 对实例的每个三角形
      for (var i = 0; i < numVertices; i += 3) {
        var v0 = modelMatrix.transformed3(
            Vector3(vertices[i], vertices[i + 1], vertices[i + 2]));
        var v1 = modelMatrix.transformed3(
            Vector3(vertices[i + 3], vertices[i + 4], vertices[i + 5]));
        var v2 = modelMatrix.transformed3(
            Vector3(vertices[i + 6], vertices[i + 7], vertices[i + 8]));
        // 计算交点
        var e1 = v1 - v0;
        var e2 = v2 - v0;
        var p = rayDirection.cross(e2);
        var det = e1.dot(p);
        if (det > -0.00001 && det < 0.00001) continue; // 平行
        var f = 1 / det;
        var s = cameraPos - v0;
        var u = f * s.dot(p);
        if (u < 0 || u > 1) continue;
        var q = s.cross(e1);
        var v = f * rayDirection.dot(q);
        if (v < 0 || u + v > 1) continue;
        var t = f * e2.dot(q);
        if (t > 0.00001 && t < tMin) {
          tMin = t;
          selectedIdx = idx;
        }
      }
    }
    return (index: selectedIdx, t: tMin);
  }

  // 模型变换
  void transform(int index, Vector3 positionDelta, Quaternion rotationDelta,
      double scaleDelta) {
    instancePosition[index] += positionDelta;
    instanceRotation[index] = rotationDelta * instanceRotation[index];
    instanceScale[index] += scaleDelta;
  }

  // 模型运动
  void update(int millis, Vector3 gravity) {
    for (var i = 0; i < instancePosition.length; i++) {
      // 位移更新
      var tmp = Vector3.copy(instanceVelocity[i]);
      tmp.scale(millis / 1000);
      instancePosition[i] += tmp;
      // 速度更新
      if(instanceState[i] == ImportedModelState.inAir) {
        tmp = Vector3.copy(gravity);
        tmp.scale(millis / 1000);
        instanceVelocity[i] += tmp;
      }
    }
  }
}
