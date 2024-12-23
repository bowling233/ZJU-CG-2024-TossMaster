#version 330 core
out vec4 FragColor;

in vec3 FragPos;
in vec2 TexCoord;
in vec3 Normal;

uniform sampler2D texture1; // 纹理采样器

void main() {
    FragColor = texture(texture1, TexCoord);  // 纹理采样结果
}