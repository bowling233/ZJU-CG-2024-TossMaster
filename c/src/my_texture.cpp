#include "my_texture.h"

#include <iostream>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

Texture2D::Texture2D(std::string texPath, GLenum format) {
    glGenTextures(1, &ID);
    loadTexture(texPath, format);
}

void Texture2D::loadTexture(std::string texPath, GLenum format) {
	// 绑定 2D 纹理
	glBindTexture(GL_TEXTURE_2D, ID);

    // 设置纹理环绕方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    // 设置纹理过滤方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);	// 纹理缩小
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);				// 纹理放大
    
	// 加载图片，创建纹理
    int width, height, channels;
	stbi_set_flip_vertically_on_load(true);	// 翻转y轴
    unsigned char *data = stbi_load(texPath.c_str(), &width, &height, &channels, 0);
    if (data) {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, format, GL_UNSIGNED_BYTE, data);
        glGenerateMipmap(GL_TEXTURE_2D);	// 设置多级渐远纹理
    }
    else std::cout << "[ERROR] Failed to load texture" << std::endl;
    stbi_image_free(data);	// 释放图片资源
}