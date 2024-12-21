import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';
import 'dart:developer' as developer;

// *********************************
// from C
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
// from C done
// *********************************

initShaders(gl, vsSource, fsSource) {
  makeShader(gl, src, type) {
    var shader = gl.createShader(type);
    gl.shaderSource(shader, src);
    gl.compileShader(shader);
    var res = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
    if (res == 0 || res == false) {
      developer.log("Error compiling shader: ${gl.getShaderInfoLog(shader)}");
      return;
    }
    return shader;
  }

  // Compile shaders
  var vertexShader = makeShader(gl, vsSource, gl.VERTEX_SHADER);
  var fragmentShader = makeShader(gl, fsSource, gl.FRAGMENT_SHADER);

  // Create program
  dynamic glProgram = gl.createProgram();

  // Attach and link shaders to the program
  gl.attachShader(glProgram, vertexShader);
  gl.attachShader(glProgram, fragmentShader);
  gl.linkProgram(glProgram);
  var res = gl.getProgramParameter(glProgram, gl.LINK_STATUS);
  developer.log(" initShaders LINK_STATUS _res: $res ");
  if (res == false || res == 0) {
    developer.log("Unable to initialize the shader program");
    return null;
  }

  return glProgram;
}

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

  final image = imglib.Image(width: imageWidth, height: imageHeight);

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

      image.setPixelRgb(w, h, r, g, b);
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
