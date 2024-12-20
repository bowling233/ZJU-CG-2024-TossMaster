# OpenGL

## flutter_gl 的工作方式

### FBO

使用 flutter_gl 时，我们不再有 glfw 等方便的初始化代码，因此有很多工作现在需要我们自己完成。

首先接触到的就是 FBO。参考 [帧缓冲 - LearnOpenGL-CN](https://learnopengl-cn.readthedocs.io/zh/latest/04%20Advanced%20OpenGL/05%20Framebuffers/)，以前 GLFW 在创建窗口时为我们创建好了 FBO。现在，flutter_gl 要求我们自己创建 FBO，并在渲染完成后调用它的方法将 FBO 传递给 Native 代码。

按照参考资料，执行的步骤如下：

- 创建 FBO，绑定为默认 FBO
- 创建纹理附件，作为 FBO 的颜色缓冲附件
- 接下来的所有渲染都渲染到颜色纹理上。
- 然后把纹理绘制到四边形，铺满整个屏幕。

对于 flutter_gl demo，需要补上深度缓冲附件。

flutter_gl 库在每次渲染循环的最后使用 updateTexture 方法传递纹理给 Native 代码，令 Widget 更新。我们追溯一下该方法的实现，在 Kotlin 中如下：

```kotlin
fun updateTexture(sourceTexture: Int): Boolean {
        this.execute {
                eglEnv.makeCurrent()

                glBindFramebuffer(GL_FRAMEBUFFER, 0)

                glClearColor(0.0f, 0.0f, 0.0f, 0.0f)
                glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

                this.worker.renderTexture(sourceTexture, null)

                glFinish()

                checkGlError()
                eglEnv.swapBuffers()
        }
        return true
}
```

可以看到这其实就是参考资料中渲染循环的第二轮。注意到这里仍然没有看见屏幕四边形所使用的着色器，所以我们继续追溯 renderTexture 方法：

```kotlin
fun renderTexture(texture: Int, matrix: FloatArray?) {
    drawTexture(texture, vertexBuffer4FBO, textureBuffer4FBO, matrix)
}

fun drawTexture(
    texture: Int,
    vertexBuffer: FloatBuffer,
    textureBuffer: FloatBuffer,
    matrix: FloatArray?
) {
    val program = getProgram()
    glUseProgram(program)

    glActiveTexture(GL_TEXTURE10)
    glBindTexture(GL_TEXTURE_2D, texture)
    glUniform1i(glGetUniformLocation(program, "Texture0"), 10)

    var resultMatrix = floatArrayOf(
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    )

    if (matrix != null) {
        resultMatrix = matrix
    }
    val matrixUniform = glGetUniformLocation(program, "matrix")
    glUniformMatrix4fv(matrixUniform, 1, false, resultMatrix, 0)

    val positionSlot = 0
    val textureSlot = 1

    glEnableVertexAttribArray(positionSlot)
    glEnableVertexAttribArray(textureSlot)

    vertexBuffer.position(0)
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, false, 0, vertexBuffer)

    textureBuffer.position(0)
    glVertexAttribPointer(textureSlot, 2, GL_FLOAT, false, 0, textureBuffer)

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)
}
```

看到这个 resultMatrix 就可以确定这是屏幕四边形的渲染函数了，着色器在旁边的文件中。

现在我们理解了第二轮上屏渲染的过程，接下来只需要关注第一轮离屏渲染。

### 纹理

关于纹理的几个概念辨析，参考 [Terminology: texture target vs texture unit vs texture image unit, etc... help! - OpenGL / OpenGL: Basic Coding - Khronos Forums](https://community.khronos.org/t/terminology-texture-target-vs-texture-unit-vs-texture-image-unit-etc-help/105441)
