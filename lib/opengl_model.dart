import 'dart:io';
import 'dart:typed_data';
import 'dart:developer';
import 'package:flutter_gl/native-array/NativeArray.app.dart';
import 'package:vector_math/vector_math.dart';
import 'package:image/image.dart';

class ImportedModel {
  final int numVertices;
  final List<Matrix4> modelMatrix = [];
  List<double> vertices;
  final List<bool> selected = [];
  final int vao;
  final List<dynamic> vbo;
  final int texture;

  factory ImportedModel(gl, String objPath, String texPath) {
    // 顶点数据：解析 OBJ 文件
    final List<double> vertVals = [];
    final List<double> triangleVerts = [];
    final List<double> textureCoords = [];
    final List<double> stVals = [];
    final List<double> normals = [];
    final List<double> normVals = [];

    final file = File(objPath);
    final lines = file.readAsLinesSync();

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

    // 顶点数据：载入 OpenGL
    final vao = gl.createVertexArray();
    gl.bindVertexArray(vao);

    final vbo = List.generate(4, (i) => gl.createBuffer());
    // 0. vertex 1. texture 2. normal 3. m_matrix
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
    // 注意：matrix 特殊，vetexAttribPointer 大小最多为 4，需要用 Stride 来实现
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[3]);
    // 注意：实例数据在渲染时传入
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

    // 纹理数据
    var img =
        decodeImage(File(texPath).readAsBytesSync())!.convert(numChannels: 4);
    img = flipVertical(img);
    var textureData = NativeUint8Array.from(img.toUint8List());
    var texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, img.width, img.height, 0, gl.RGBA,
        gl.UNSIGNED_BYTE, textureData);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    return ImportedModel._internal(numVertices, vao, vbo, texture, triangleVerts);
  }

  ImportedModel._internal(this.numVertices, this.vao, this.vbo, this.texture, this.vertices);

  void instantiate(gl, Matrix4 modelMatrix) {
    this.modelMatrix.add(modelMatrix);
    selected.add(false);
  }

  // 渲染
  void render(gl) {
    // 模型数据
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[0]);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[1]);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[2]);
    // 模型实例矩阵
    if (modelMatrix.isEmpty) return;
    List<double> mMatrix = [];
    for (var i = 0; i < modelMatrix.length; i++) {
      mMatrix.addAll(modelMatrix[i].storage);
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[3]);
    gl.bufferData(gl.ARRAY_BUFFER, mMatrix.length * Float32List.bytesPerElement,
        Float32List.fromList(mMatrix), gl.STATIC_DRAW);
    // 纹理
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    // 实例化绘制
    gl.drawArraysInstanced(gl.TRIANGLES, 0, numVertices, modelMatrix.length);
    log('[ImportedModel.render()] drawArraysInstanced: ${modelMatrix.length}');
  }

  // 给定 pMat，标准设备坐标，返回选中的模型
  ({int index,double t}) hisTest(Vector2 ndc, Vector3 cameraPos, Matrix4 vMat, Matrix4 pMat) {
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
    for (final model in modelMatrix) {
      // 对实例的每个三角形
      for (var i = 0; i < numVertices; i += 3) {
        var v0 = model.transformed3(Vector3(vertices[i], vertices[i + 1], vertices[i + 2]));
        var v1 = model.transformed3(Vector3(vertices[i + 3], vertices[i + 4], vertices[i + 5]));
        var v2 = model.transformed3(Vector3(vertices[i + 6], vertices[i + 7], vertices[i + 8]));
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
          selectedIdx = modelMatrix.indexOf(model);
        }
      }
    }
    return (index: selectedIdx, t: tMin);
  }
}
