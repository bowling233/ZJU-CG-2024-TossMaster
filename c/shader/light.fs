#version 330 core
out vec4 FragColor;

in vec2 TexCoord;

// 纹理采样器
uniform sampler2D texture1;

void main() {
    FragColor = texture(texture1, TexCoord);
}