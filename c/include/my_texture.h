#ifndef __TEXTURE_H__
#define __TEXTURE_H__

#include <string>
#include <glad/glad.h>
#include <GLFW/glfw3.h>

class Texture2D {
public:
    unsigned int ID;
    // int Width, Height; // Width and height of loaded image in pixels
    // // Texture Format
    // int Internal_Format; // Format of texture object
    // int Image_Format; // Format of loaded image
    // // Texture configuration
    // int Wrap_S; // Wrapping mode on S axis
    // int Wrap_T; // Wrapping mode on T axis
    // int Filter_Min; // Filtering mode if texture pixels < screen pixels
    // int Filter_Max; // Filtering mode if texture pixels > screen pixels

    Texture2D() {};
    Texture2D(std::string texPath, GLenum format);
    void loadTexture(std::string texPath, GLenum format);
    void bind() const { glBindTexture(GL_TEXTURE_2D, ID); }
};

#endif