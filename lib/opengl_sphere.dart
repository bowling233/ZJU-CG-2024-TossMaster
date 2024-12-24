import 'dart:math';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:vector_math/vector_math.dart';
import 'opengl_model.dart';

class Sphere {
  // 模型数据
  final int numVertices;
  final int numIndices;
  final int vao;
  final List<dynamic> vbo;
  // 实例数据
  final List<Vector3> instancePosition = [];
  final List<Vector3> instanceVelocity = [];
  final List<double> instanceScale = [];
  final List<int> instanceFlag = [];

  factory Sphere(gl, {int precision = 48}) {
    // 顶点数据：生成球体
    final numVertices = (precision + 1) * (precision + 1);
    final numIndices = precision * precision * 6;

    final vertices = List.generate(numVertices, (_) => Vector3.zero());
    final texCoords = List.generate(numVertices, (_) => Vector2.zero());
    final normals = List.generate(numVertices, (_) => Vector3.zero());
    final tangents = List.generate(numVertices, (_) => Vector3.zero());
    final indices = List.generate(numIndices, (_) => 0);

    for (int i = 0; i <= precision; i++) {
      for (int j = 0; j <= precision; j++) {
        double y = cos(radians(180.0 - i * 180.0 / precision));
        double x = -cos(radians(j * 360.0 / precision)) * cos(asin(y)).abs();
        double z = sin(radians(j * 360.0 / precision)) * cos(asin(y)).abs();

        vertices[i * (precision + 1) + j] = Vector3(x, y, z);
        texCoords[i * (precision + 1) + j] =
            Vector2(j / precision, i / precision);
        normals[i * (precision + 1) + j] = Vector3(x, y, z);

        // calculate tangent vector
        if ((x == 0 && y == 1 && z == 0) || (x == 0 && y == -1 && z == 0)) {
          tangents[i * (precision + 1) + j] = Vector3(0.0, 0.0, -1.0);
        } else {
          tangents[i * (precision + 1) + j] =
              Vector3(0.0, 1.0, 0.0).cross(Vector3(x, y, z));
        }
      }
    }

    for (int i = 0; i < precision; i++) {
      for (int j = 0; j < precision; j++) {
        indices[6 * (i * precision + j) + 0] = i * (precision + 1) + j;
        indices[6 * (i * precision + j) + 1] = i * (precision + 1) + j + 1;
        indices[6 * (i * precision + j) + 2] = (i + 1) * (precision + 1) + j;
        indices[6 * (i * precision + j) + 3] = i * (precision + 1) + j + 1;
        indices[6 * (i * precision + j) + 4] =
            (i + 1) * (precision + 1) + j + 1;
        indices[6 * (i * precision + j) + 5] = (i + 1) * (precision + 1) + j;
      }
    }

    // 顶点数据：载入 OpenGL

    List<double> pvalues = [];
    List<double> tvalues = [];
    List<double> nvalues = [];

    for (var i = 0; i < numIndices; i++) {
      pvalues.addAll(vertices[indices[i]].storage);
      tvalues.addAll(texCoords[indices[i]].storage);
      nvalues.addAll(normals[indices[i]].storage);
    }

    final vao = gl.createVertexArray();
    gl.bindVertexArray(vao);

    final vbo = List.generate(5, (_) => gl.createBuffer());
    // 0.vertex 1. texture 2. normal 3-6. instanceMatrix 7. instanceFlag 8. EBO

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

    // 实例数据预分配
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

    return Sphere._internal(
      numVertices,
      numIndices,
      vao,
      vbo,
    );
  }

  // Private named constructor to initialize the sphere
  Sphere._internal(
    this.numVertices,
    this.numIndices,
    this.vao,
    this.vbo,
  );

  // 实例化
  instantiate() {
    instancePosition.add(Vector3(0.0, 0.0, 0.0));
    instanceVelocity.add(Vector3(0.0, 0.0, 0.0));
    instanceScale.add(1.0);
    instanceFlag.add(2);
  }

  render(gl) {
    if (instancePosition.isEmpty) {
      developer.log('No instance to render');
      return;
    }
    // 模型数据
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[0]);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[1]);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo[2]);
    // 解除纹理绑定
    gl.bindTexture(gl.TEXTURE_2D, 0);
    // 实例数据
    List<double> mMatrix = [];
    for (var i = 0; i < instancePosition.length; i++) {
      var modelMatrix = Matrix4.compose(instancePosition[i],
          Quaternion.identity(), Vector3.all(instanceScale[i]));
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
        gl.TRIANGLES, 0, numIndices, instancePosition.length);
  }

  // 模型移动
  void update(int millis, Vector3 gravity) {
    for (var i = 0; i < instancePosition.length; i++) {
      // 位移更新
      var tmp = Vector3.copy(instanceVelocity[i]);
      tmp.scale(millis / 1000);
      instancePosition[i] += tmp;
      // 速度更新
      tmp = Vector3.copy(gravity);
      tmp.scale(millis / 1000);
      instanceVelocity[i] += tmp;
    }
  }

  // 碰撞检测
  bool collision(
      int idxBall, // 需要检测碰撞的实例
      ImportedModel model, // 碰撞检测的模型
      int idxBox // 碰撞检测的模型实例
      ) {
    var diff = instancePosition[idxBall] - model.instancePosition[idxBox];
    var clampedX = diff.x;
    var clampedY = diff.y;
    var clampedZ = diff.z;
    var halfSizeX = model.halfSize.x * model.instanceScale[idxBox];
    var halfSizeY = model.halfSize.y * model.instanceScale[idxBox];
    var halfSizeZ = model.halfSize.z * model.instanceScale[idxBox];

    if (clampedX < -model.halfSize.x) clampedX = -halfSizeX;
    if (clampedX > model.halfSize.x) clampedX = halfSizeX;
    if (clampedY < -model.halfSize.y) clampedY = -halfSizeY;
    if (clampedY > model.halfSize.y) clampedY = halfSizeY;
    if (clampedZ < -model.halfSize.z) clampedZ = -halfSizeZ;
    if (clampedZ > model.halfSize.z) clampedZ = halfSizeZ;

    diff = Vector3(clampedX, clampedY, clampedZ) - diff;

    return diff.length < instanceScale[idxBall];
  }
}
