import 'dart:io';
import 'dart:typed_data';
import 'dart:developer';
import 'package:flutter_gl/native-array/NativeArray.app.dart';
import 'package:vector_math/vector_math.dart';
import 'package:vector_math/vector_math_lists.dart';
import 'package:image/image.dart';

class ImportedModel {
  final int numVertices;
  final List<Matrix4> modelMatrix = [];
  final int vao;
  final List<dynamic> vbo;
  final int texture;

  factory ImportedModel(gl, String objPath, String texPath) {
    final modelImporter = ModelImporter();
    modelImporter.parseOBJ(objPath);

    final numVertices = modelImporter.getNumVertices();
    final verts = modelImporter.getVertices();
    final tcs = modelImporter.getTextureCoordinates();
    final normals = modelImporter.getNormals();

    final vertices = List.generate(numVertices,
        (i) => Vector3(verts[i * 3], verts[i * 3 + 1], verts[i * 3 + 2]));
    final texCoords =
        List.generate(numVertices, (i) => Vector2(tcs[i * 2], tcs[i * 2 + 1]));
    final normalVecs = List.generate(numVertices,
        (i) => Vector3(normals[i * 3], normals[i * 3 + 1], normals[i * 3 + 2]));

    Vector3List pvalues = Vector3List(numVertices);
    Vector2List tvalues = Vector2List(numVertices);
    Vector3List nvalues = Vector3List(numVertices);

    for (var i = 0; i < numVertices; i++) {
      pvalues.store(i, vertices[i]);
      tvalues.store(i, texCoords[i]);
      nvalues.store(i, normalVecs[i]);
    }

    final vao = gl.createVertexArray();
    gl.bindVertexArray(vao);

    final vbo = List.generate(4, (i) => gl.createBuffer());
    // 0. vertex 1. texture 2. normal 3. m_matrix
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[0]);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        pvalues.buffer.length * Float32List.bytesPerElement,
        pvalues.buffer,
        gl.STATIC_DRAW);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(0);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[1]);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        tvalues.buffer.length * Float32List.bytesPerElement,
        tvalues.buffer,
        gl.STATIC_DRAW);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(1);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[2]);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        nvalues.buffer.length * Float32List.bytesPerElement,
        nvalues.buffer,
        gl.STATIC_DRAW);
    gl.vertexAttribPointer(2, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(2);
    // matrix 特殊，vetexAttribPointer 大小最多为 4，需要用 Stride 来实现
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[3]);
    // 数据在渲染时传入
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

    return ImportedModel._internal(numVertices, vao, vbo, texture);
  }

  ImportedModel._internal(this.numVertices, this.vao, this.vbo, this.texture);

  void instantiate(gl, Matrix4 modelMatrix) {
    this.modelMatrix.add(modelMatrix);
  }

  void render(gl) {
    if (modelMatrix.isEmpty) return;
    List<double> mMatrix = [];
    for (var i = 0; i < modelMatrix.length; i++) {
      mMatrix.addAll(modelMatrix[i].storage);
    }
    log('[ImportedModel.render()] mMatrix: ${mMatrix.length}');
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[0]);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[1]);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[2]);
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
}

class ModelImporter {
  final List<double> vertVals = [];
  final List<double> triangleVerts = [];
  final List<double> textureCoords = [];
  final List<double> stVals = [];
  final List<double> normals = [];
  final List<double> normVals = [];

  void parseOBJ(String filePath) {
    final file = File(filePath);
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
  }

  int getNumVertices() => (triangleVerts.length ~/ 3);
  List<double> getVertices() => triangleVerts;
  List<double> getTextureCoordinates() => textureCoords;
  List<double> getNormals() => normals;
}
