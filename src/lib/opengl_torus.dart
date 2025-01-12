import 'dart:math';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:vector_math/vector_math.dart';

class Torus {
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

  factory Torus(gl, {double inner = 0.5, double outer = 0.2, int prec = 48}) {
    final numVertices = (prec + 1) * (prec + 1);
    final numIndices = prec * prec * 6;

    final vertices = List.generate(numVertices, (_) => Vector3.zero());
    final texCoords = List.generate(numVertices, (_) => Vector2.zero());
    final normals = List.generate(numVertices, (_) => Vector3.zero());
    final sTangents = List.generate(numVertices, (_) => Vector3.zero());
    final tTangents = List.generate(numVertices, (_) => Vector3.zero());
    final indices = List.generate(numIndices, (_) => 0);

    for (int i = 0; i <= prec; i++) {
      double amt = radians(i * 360.0 / prec);

      final rMat = Matrix4.rotationZ(amt);
      final initPos = rMat.transform3(Vector3(0.0, outer, 0.0));
      vertices[i] = initPos + Vector3(inner, 0.0, 0.0);

      texCoords[i] = Vector2(0.0, i / prec);

      final tangentRot = Matrix4.rotationZ(amt + (pi / 2.0));
      tTangents[i] = tangentRot.transform3(Vector3(0.0, -1.0, 0.0));

      sTangents[i] = Vector3(0.0, 0.0, -1.0);
      normals[i] = tTangents[i].cross(sTangents[i]);
    }

    for (int ring = 1; ring <= prec; ring++) {
      for (int i = 0; i <= prec; i++) {
        double amt = radians(ring * 360.0 / prec);
        final rMat = Matrix4.rotationY(amt);

        var tmp = Vector3.copy(vertices[i]);
        vertices[ring * (prec + 1) + i] = rMat.transform3(tmp);
        texCoords[ring * (prec + 1) + i] =
            Vector2(ring * 2.0 / prec, texCoords[i].y);

        tmp = Vector3.copy(sTangents[i]);
        sTangents[ring * (prec + 1) + i] = rMat.transform3(tmp);
        tmp = Vector3.copy(tTangents[i]);
        tTangents[ring * (prec + 1) + i] = rMat.transform3(tmp);
        tmp = Vector3.copy(normals[i]);
        normals[ring * (prec + 1) + i] = rMat.transform3(tmp);
      }
    }

    for (int ring = 0; ring < prec; ring++) {
      for (int i = 0; i < prec; i++) {
        indices[((ring * prec + i) * 2) * 3 + 0] = ring * (prec + 1) + i;
        indices[((ring * prec + i) * 2) * 3 + 1] = (ring + 1) * (prec + 1) + i;
        indices[((ring * prec + i) * 2) * 3 + 2] = ring * (prec + 1) + i + 1;
        indices[((ring * prec + i) * 2 + 1) * 3 + 0] =
            ring * (prec + 1) + i + 1;
        indices[((ring * prec + i) * 2 + 1) * 3 + 1] =
            (ring + 1) * (prec + 1) + i;
        indices[((ring * prec + i) * 2 + 1) * 3 + 2] =
            (ring + 1) * (prec + 1) + i + 1;
      }
    }

    List<double> pvalues = [];
    List<double> tvalues = [];
    List<double> nvalues = [];

    for (var i = 0; i < numVertices; i++) {
      pvalues.addAll(vertices[indices[i]].storage);
      tvalues.addAll(texCoords[indices[i]].storage);
      nvalues.addAll(normals[indices[i]].storage);
    }

    final vao = gl.createVertexArray();
    gl.bindVertexArray(vao);

    final vbo = List.generate(6, (_) => gl.createBuffer());
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

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, vbo[5]);
    gl.bufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        indices.length * Int32List.bytesPerElement,
        Int32List.fromList(indices),
        gl.STATIC_DRAW);

    return Torus._internal(numVertices, numIndices, vao, vbo);
  }

  Torus._internal(
    this.numVertices,
    this.numIndices,
    this.vao,
    this.vbo,
  );

  instantiate() {
    instancePosition.add(Vector3.zero());
    instanceVelocity.add(Vector3.zero());
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
    gl.drawElementsInstanced(
        gl.TRIANGLES, numIndices, gl.UNSIGNED_INT, 0, instancePosition.length);
  }
}
