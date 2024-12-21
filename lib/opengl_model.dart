import 'dart:io';
import 'package:vector_math/vector_math.dart';

class ImportedModel {
  final int numVertices;
  final List<Vector3> vertices;
  final List<Vector2> texCoords;
  final List<Vector3> normalVecs;

  // Factory constructor to create an ImportedModel from a file path
  factory ImportedModel(String filePath) {
    final modelImporter = ModelImporter();
    modelImporter.parseOBJ(filePath);

    final numVertices = modelImporter.getNumVertices();
    final verts = modelImporter.getVertices();
    final tcs = modelImporter.getTextureCoordinates();
    final normals = modelImporter.getNormals();

    final vertices = List.generate(
        numVertices,
        (i) => Vector3(
            verts[i * 3], verts[i * 3 + 1], verts[i * 3 + 2]));
    final texCoords = List.generate(
        numVertices, (i) => Vector2(tcs[i * 2], tcs[i * 2 + 1]));
    final normalVecs = List.generate(
        numVertices,
        (i) => Vector3(
            normals[i * 3], normals[i * 3 + 1], normals[i * 3 + 2]));

    return ImportedModel._internal(numVertices, vertices, texCoords, normalVecs);
  }

  ImportedModel._internal(
      this.numVertices, this.vertices, this.texCoords, this.normalVecs);

  int getNumVertices() => numVertices;
  List<Vector3> getVertices() => vertices;
  List<Vector2> getTextureCoords() => texCoords;
  List<Vector3> getNormals() => normalVecs;
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