import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_gl/native-array/NativeArray.app.dart';
import 'package:vector_math/vector_math.dart';
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

    List<double> pvalues = [];
    List<double> tvalues = [];
    List<double> nvalues = [];

    for (var i = 0; i < numVertices; i++) {
      pvalues.add(vertices[i].x);
      pvalues.add(vertices[i].y);
      pvalues.add(vertices[i].z);
      tvalues.add(texCoords[i].x);
      tvalues.add(texCoords[i].y);
      nvalues.add(normalVecs[i].x);
      nvalues.add(normalVecs[i].y);
      nvalues.add(normalVecs[i].z);
    }

    final vao = gl.createVertexArray();
    gl.bindVertexArray(vao);

    final vbo = List.generate(3, (i) => gl.createBuffer());
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[0]);
    gl.bufferData(gl.ARRAY_BUFFER, pvalues.length * Float32List.bytesPerElement,
        Float32List.fromList(pvalues), gl.STATIC_DRAW);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(0);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[1]);
    gl.bufferData(gl.ARRAY_BUFFER, tvalues.length * Float32List.bytesPerElement,
        Float32List.fromList(tvalues), gl.STATIC_DRAW);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(1);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[2]);
    gl.bufferData(gl.ARRAY_BUFFER, nvalues.length * Float32List.bytesPerElement,
        Float32List.fromList(nvalues), gl.STATIC_DRAW);
    gl.vertexAttribPointer(2, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(2);

    var img =
        decodeImage(File(texPath).readAsBytesSync())!.convert(numChannels: 4);
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
