#version 330 core
out vec4 FragColor;

struct PointLight {
    vec3 position;
    vec3 color;
};

#define LIGHT_NUM 2		// 光源数量

in vec3 FragPos;
in vec2 TexCoord;
in vec3 Normal;

uniform vec3 viewPos;
uniform PointLight pointLights[LIGHT_NUM];
uniform sampler2D texture1; // 纹理采样器

vec3 CalcReflection(PointLight light);

void main() {
    // 环境光照
    float ambientStrength = 0.5;
    vec3 ambient = ambientStrength * vec3(1.0, 1.0, 1.0);

    vec3 result = ambient;

    for(int i = 0; i < LIGHT_NUM; i++)
        result += CalcReflection(pointLights[i]);

    FragColor = vec4(result, 1.0) * texture(texture1, TexCoord);  // 光照系数*纹理采样结果
}

// 计算 Phong Model 中漫反射+镜面反射
vec3 CalcReflection(PointLight light) {
    // 漫反射
    float diffStrength = 0.6;                   // 漫反射系数
    vec3 norm = normalize(Normal);              // 法向量
    vec3 lightDir = normalize(light.position - FragPos);    // 光线入射方向
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diffStrength * diff * light.color;       // 漫反射
    
    // 镜面反射
    float specularStrength = 0.6;               // 镜面反射系数
    vec3 viewDir = normalize(viewPos - FragPos);// 观察方向
    vec3 reflectDir = reflect(-lightDir, norm); // 反射方向
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    vec3 specular = specularStrength * spec * light.color;  // 镜面反射

    return diffuse + specular;
}