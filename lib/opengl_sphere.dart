import 'dart:math';
import 'package:vector_math/vector_math.dart';

class Sphere {
  late int numVertices;
  late int numIndices;
  late List<int> indices;
  late List<Vector3> vertices;
  late List<Vector2> texCoords;
  late List<Vector3> normals;
  late List<Vector3> tangents;

  // Factory constructor for creating a Sphere object
  factory Sphere({int precision = 48}) {
    return Sphere._internal(precision);
  }

  // Private named constructor to initialize the sphere
  Sphere._internal(int prec) {
    init(prec);
  }

  // Initialize the sphere geometry
  void init(int prec) {
    numVertices = (prec + 1) * (prec + 1);
    numIndices = prec * prec * 6;

    vertices = List.generate(numVertices, (_) => Vector3.zero());
    texCoords = List.generate(numVertices, (_) => Vector2.zero());
    normals = List.generate(numVertices, (_) => Vector3.zero());
    tangents = List.generate(numVertices, (_) => Vector3.zero());
    indices = List.generate(numIndices, (_) => 0);

    // calculate triangle vertices
    for (int i = 0; i <= prec; i++) {
      for (int j = 0; j <= prec; j++) {
        double y = cos(radians(180.0 - i * 180.0 / prec));
        double x =
            -cos(radians(j * 360.0 / prec)) * cos(asin(y)).abs();
        double z =
            sin(radians(j * 360.0 / prec)) * cos(asin(y)).abs();

        vertices[i * (prec + 1) + j] = Vector3(x, y, z);
        texCoords[i * (prec + 1) + j] = Vector2(j / prec, i / prec);
        normals[i * (prec + 1) + j] = Vector3(x, y, z);

        // calculate tangent vector
        if ((x == 0 && y == 1 && z == 0) || (x == 0 && y == -1 && z == 0)) {
          tangents[i * (prec + 1) + j] = Vector3(0.0, 0.0, -1.0);
        } else {
          tangents[i * (prec + 1) + j] =
              Vector3(0.0, 1.0, 0.0).cross(Vector3(x, y, z));
        }
      }
    }

    // calculate triangle indices
    for (int i = 0; i < prec; i++) {
      for (int j = 0; j < prec; j++) {
        indices[6 * (i * prec + j) + 0] = i * (prec + 1) + j;
        indices[6 * (i * prec + j) + 1] = i * (prec + 1) + j + 1;
        indices[6 * (i * prec + j) + 2] = (i + 1) * (prec + 1) + j;
        indices[6 * (i * prec + j) + 3] = i * (prec + 1) + j + 1;
        indices[6 * (i * prec + j) + 4] = (i + 1) * (prec + 1) + j + 1;
        indices[6 * (i * prec + j) + 5] = (i + 1) * (prec + 1) + j;
      }
    }
  }

  int getNumVertices() => numVertices;

  int getNumIndices() => numIndices;

  List<int> getIndices() => indices;

  List<Vector3> getVertices() => vertices;

  List<Vector2> getTexCoords() => texCoords;

  List<Vector3> getNormals() => normals;

  List<Vector3> getTangents() => tangents;
}
