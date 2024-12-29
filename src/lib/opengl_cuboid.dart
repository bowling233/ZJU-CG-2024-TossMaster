import 'dart:typed_data';
import 'dart:developer';
import 'package:vector_math/vector_math.dart';
import 'opengl_model.dart';
import 'opengl_sphere.dart' as sphere;

class Cuboid {
  // 模型数据
  final int numVertices;
  final int vao;
  final List<dynamic> vbo;
  final Vector3 halfSize;
  // 实例数据
  final List<Vector3> instancePosition = [];
  final List<Vector3> instanceVelocity = [];
  final List<double> instanceScale = [];
  final List<int> instanceFlag = [];

  factory Cuboid(gl,
      {double length = 30, double width = 30, double height = 0.2}) {
    // 顶点数据：生成立方体
    final numVertices = 36;

    // 顶点数据：载入 OpenGL
    List<double> pvalues = [
      length / 2,
      -height / 2,
      -width / 2,
      -length / 2,
      -height / 2,
      -width / 2,
      -length / 2,
      height / 2,
      -width / 2,
      -length / 2,
      height / 2,
      -width / 2,
      length / 2,
      height / 2,
      -width / 2,
      length / 2,
      -height / 2,
      -width / 2,
      length / 2,
      height / 2,
      -width / 2,
      length / 2,
      -height / 2,
      width / 2,
      length / 2,
      -height / 2,
      -width / 2,
      length / 2,
      height / 2,
      -width / 2,
      length / 2,
      height / 2,
      width / 2,
      length / 2,
      -height / 2,
      width / 2,
      length / 2,
      height / 2,
      width / 2,
      -length / 2,
      -height / 2,
      width / 2,
      length / 2,
      -height / 2,
      width / 2,
      length / 2,
      height / 2,
      width / 2,
      -length / 2,
      height / 2,
      width / 2,
      -length / 2,
      -height / 2,
      width / 2,
      -length / 2,
      height / 2,
      width / 2,
      -length / 2,
      -height / 2,
      -width / 2,
      -length / 2,
      -height / 2,
      width / 2,
      -length / 2,
      height / 2,
      width / 2,
      -length / 2,
      height / 2,
      -width / 2,
      -length / 2,
      -height / 2,
      -width / 2,
      length / 2,
      -height / 2,
      -width / 2,
      length / 2,
      -height / 2,
      width / 2,
      -length / 2,
      -height / 2,
      width / 2,
      -length / 2,
      -height / 2,
      width / 2,
      -length / 2,
      -height / 2,
      -width / 2,
      length / 2,
      -height / 2,
      -width / 2,
      length / 2,
      height / 2,
      width / 2,
      length / 2,
      height / 2,
      -width / 2,
      -length / 2,
      height / 2,
      -width / 2,
      -length / 2,
      height / 2,
      -width / 2,
      -length / 2,
      height / 2,
      width / 2,
      length / 2,
      height / 2,
      width / 2,
    ];
    List<double> tvalues = [];
    List<double> nvalues = [
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

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

    return Cuboid._internal(
        numVertices, vao, vbo, Vector3(length / 2, height / 2, width / 2));
  }

  Cuboid._internal(
    this.numVertices,
    this.vao,
    this.vbo,
    this.halfSize,
  );

  // 实例化
  instantiate() {
    instancePosition.add(Vector3(0.0, -14.0, -30.0));
    instanceVelocity.add(Vector3(0.0, 0.0, 0.0));
    instanceScale.add(1.0);
    instanceFlag.add(2);
  }

  render(gl) {
    if (instancePosition.isEmpty) {
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
        gl.TRIANGLES, 0, numVertices, instancePosition.length);
  }

  bool collisionModel(
    int idxCuboid,
    ImportedModel model,
    int idxModel,
  ) {
    // 如果 model 的包围盒下界大于 cuboid 的上界，返回 false
    var modelMin = model.instancePosition[idxModel] - model.halfSize;
    var cuboidMax = instancePosition[idxCuboid] + halfSize;
    if (modelMin.y > cuboidMax.y) {
      return false;
    }
    // 如果衰减到一定程度，停止运动
    if (model.instanceVelocity[idxModel].y.abs() < 0.5) {
      model.instanceVelocity[idxModel].y = 0.0;
      model.instanceState[idxModel] = ImportedModelState.onBoard;
    }
    // 否则返回 true，反向并衰减模型的速度
    model.instanceVelocity[idxModel].y =
        -model.instanceVelocity[idxModel].y * 0.8;

    return true;
  }

  bool collisionSphere(
    int idxCuboid,
    sphere.Sphere sphere,
    int idxSphere,
  ) {
    // 如果球体底部高于立方体顶部，返回 false
    var sphereMin = sphere.instancePosition[idxSphere] -
        Vector3(0.0, sphere.instanceScale[idxSphere], 0.0);
    var cuboidMax = instancePosition[idxCuboid] + halfSize;
    if (sphereMin.y > cuboidMax.y) {
      return false;
    }
    return true;
  }
}
