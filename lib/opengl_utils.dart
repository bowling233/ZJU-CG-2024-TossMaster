import 'dart:collection';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';
import 'package:vector_math/vector_math.dart';

// *********************************
// OpenGL 材质
// *********************************

enum GlMaterial { gold, silver, bronze, jade, pearl }

typedef GlMaterialEntry = DropdownMenuEntry<GlMaterialLabel>;

enum GlMaterialLabel {
  gold('Gold', goldAmbient),
  silver('Silver', silverAmbient),
  bronze('Bronze', bronzeAmbient),
  jade('Jade', jadeAmbient),
  pearl('Pearl', pearlAmbient);

  const GlMaterialLabel(this.label, this.ambient);
  final String label;
  final List<double> ambient;

  static final List<GlMaterialEntry> entries =
      UnmodifiableListView<GlMaterialEntry>(
    values.map<GlMaterialEntry>(
      (GlMaterialLabel material) => GlMaterialEntry(
        value: material,
        label: material.label,
        enabled: true,
        style: MenuItemButton.styleFrom(
          foregroundColor: Color.fromRGBO(
            (material.ambient[0] * 255).toInt(),
            (material.ambient[1] * 255).toInt(),
            (material.ambient[2] * 255).toInt(),
            material.ambient[3],
          ),
        ),
      ),
    ),
  );
}

// 金材质
const List<double> goldAmbient = [0.2473, 0.1995, 0.0745, 1.0];
const List<double> goldDiffuse = [0.7516, 0.6065, 0.2265, 1.0];
const List<double> goldSpecular = [0.6283, 0.5559, 0.3661, 1.0];
const double goldShininess = 51.2;
// 银材质
const List<double> silverAmbient = [0.1923, 0.1923, 0.1923, 1.0];
const List<double> silverDiffuse = [0.5075, 0.5075, 0.5075, 1.0];
const List<double> silverSpecular = [0.5083, 0.5083, 0.5083, 1.0];
const double silverShininess = 51.2;
// 铜材质
const List<double> bronzeAmbient = [0.2125, 0.1275, 0.0540, 1.0];
const List<double> bronzeDiffuse = [0.7140, 0.4284, 0.1814, 1.0];
const List<double> bronzeSpecular = [0.3936, 0.2719, 0.1667, 1.0];
const double bronzeShininess = 25.6;
// 玉材质
const List<double> jadeAmbient = [0.1350, 0.2225, 0.1575, 0.95];
const List<double> jadeDiffuse = [0.54, 0.89, 0.63, 0.95];
const List<double> jadeSpecular = [0.3162, 0.3162, 0.3162, 0.95];
const double jadeShininess = 12.8;
// 珍珠材质
const List<double> pearlAmbient = [0.25, 0.20725, 0.20725, 0.922];
const List<double> pearlDiffuse = [1.0, 0.829, 0.829, 0.922];
const List<double> pearlSpecular = [0.296648, 0.296648, 0.296648, 0.922];
const double pearlShininess = 11.264;

// *********************************
// OpenGL 模型
// *********************************

Vector2 screenToNDC(Vector2 screenCoords, Vector2 screenSize) {
  return Vector2(
    (2.0 * screenCoords.x / screenSize.x) - 1.0,
    1.0 - (2.0 * screenCoords.y / screenSize.y),
  );
}

Vector3 moveVector(Vector3 v, Vector3 dir, double vol) {
  return Vector3(v.x + dir.x * vol, v.y + dir.y * vol, v.z + dir.z * vol);
}

// *********************************
// OpenGL 纹理
// *********************************

// *********************************
// OpenGL 着色器
// *********************************

bool checkOpenGLError(gl) {
  bool foundError = false;
  // glGetError() → int
  int glErr = gl.getError();
  while (glErr != gl.NO_ERROR) {
    developer.log("OpenGL Error: $glErr");
    foundError = true;
    glErr = gl.getError();
  }
  return foundError;
}

void printShaderLog(gl, int shader) {
  // https://pub.dev/documentation/flutter_gl/latest/openGL_opengl_OpenGLContextES/OpenGLContextES/getShaderInfoLog.html
  String log = gl.getShaderInfoLog(shader);
  developer.log("Shader log: $log");
}

int prepareShader(gl, int shaderType, String shaderSrc) {
  int shaderCompiled = 0;
  // glCreateShader(int type) → int
  int shaderRef = gl.createShader(shaderType);
  if (shaderRef == 0 || shaderRef == gl.INVALID_ENUM) {
    developer.log("Error creating shader");
    return 0;
  }
  // glShaderSource(int shader, int count, Pointer<Pointer<Int8>> string, Pointer<Int32> length) → void
  /**
   * void shaderSource(v0, String shaderSource) {
  var sourceString = shaderSource.toNativeUtf8();
  var arrayPointer = calloc<Pointer<Int8>>();
  arrayPointer.value = Pointer.fromAddress(sourceString.address);
  gl.glShaderSource(v0, 1, arrayPointer, nullptr);
  calloc.free(arrayPointer);
  calloc.free(sourceString);
}
   */
  gl.shaderSource(shaderRef, shaderSrc);
  // glCompileShader(int shader) → void
  gl.compileShader(shaderRef);
  checkOpenGLError(gl);
  // glGetShaderiv(int shader, int pname, Pointer<Int32> params) → void
/**
 * int getShaderParameter(v0, v1) {
  var _pointer = calloc<Int32>();
  gl.glGetShaderiv(v0, v1, _pointer);

  final _v = _pointer.value;
  calloc.free(_pointer);

  return _v;
}
 */
  shaderCompiled = gl.getShaderParameter(shaderRef, gl.COMPILE_STATUS);
  if (shaderCompiled != gl.TRUE) {
    if (shaderType == gl.VERTEX_SHADER) {
      developer.log("Vertex ");
    } else if (shaderType == gl.FRAGMENT_SHADER) {
      developer.log("Fragment ");
    } else {
      developer.log("Unknown ");
    }
    developer.log("shader compilation error for shader: $shaderSrc");
    printShaderLog(gl, shaderRef);
  }
  return shaderRef;
}

void printProgramLog(gl, int program) {
  String log = gl.getProgramInfoLog(program);
  developer.log("Program log: $log");
}

int finalizeShaderProgram(gl, int sprogram) {
  int linked = 0;
  gl.linkProgram(sprogram);
  linked = gl.getProgramParameter(sprogram, gl.LINK_STATUS);
  if (linked != gl.TRUE) {
    developer.log("Error linking shader program");
    printProgramLog(gl, sprogram);
  }
  return sprogram;
}

int createShaderProgram(gl, String vp, String fp) {
  int vShader = prepareShader(gl, gl.VERTEX_SHADER, vp);
  int fShader = prepareShader(gl, gl.FRAGMENT_SHADER, fp);
  int vfprogram = gl.createProgram();
  gl.attachShader(vfprogram, vShader);
  gl.attachShader(vfprogram, fShader);
  finalizeShaderProgram(gl, vfprogram);
  return vfprogram;
}

// *********************************
// 相机图像转换
// *********************************

imglib.Image convertYUV420ToImage(CameraImage cameraImage) {
  final imageWidth = cameraImage.width;
  final imageHeight = cameraImage.height;

  final yBuffer = cameraImage.planes[0].bytes;
  final uBuffer = cameraImage.planes[1].bytes;
  final vBuffer = cameraImage.planes[2].bytes;

  final int yRowStride = cameraImage.planes[0].bytesPerRow;
  final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

  final int uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

  final image = imglib.Image(width: imageHeight, height: imageWidth);

  for (int h = 0; h < imageHeight; h++) {
    int uvh = (h / 2).floor();

    for (int w = 0; w < imageWidth; w++) {
      int uvw = (w / 2).floor();

      final yIndex = (h * yRowStride) + (w * yPixelStride);

      // Y plane should have positive values belonging to [0...255]
      final int y = yBuffer[yIndex];

      // U/V Values are subsampled i.e. each pixel in U/V chanel in a
      // YUV_420 image act as chroma value for 4 neighbouring pixels
      final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

      // U/V values ideally fall under [-0.5, 0.5] range. To fit them into
      // [0, 255] range they are scaled up and centered to 128.
      // Operation below brings U/V values to [-128, 127].
      final int u = uBuffer[uvIndex];
      final int v = vBuffer[uvIndex];

      // Compute RGB values per formula above.
      int r = (y + v * 1436 / 1024 - 179).round();
      int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
      int b = (y + u * 1814 / 1024 - 227).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      image.setPixelRgb(imageHeight - h - 1, imageWidth - w - 1, r, g, b);
    }
  }
  return image;
}

imglib.Image convertBGRA8888ToImage(CameraImage cameraImage) {
  return imglib.Image.fromBytes(
    width: cameraImage.planes[0].width!,
    height: cameraImage.planes[0].height!,
    bytes: cameraImage.planes[0].bytes.buffer,
    order: imglib.ChannelOrder.bgra,
  );
}

imglib.Image convertCameraImage(CameraImage cameraImage) {
  if (cameraImage.format.group == ImageFormatGroup.yuv420) {
    return convertYUV420ToImage(cameraImage);
  } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
    return convertBGRA8888ToImage(cameraImage);
  } else {
    throw Exception('Undefined image type.');
  }
}
