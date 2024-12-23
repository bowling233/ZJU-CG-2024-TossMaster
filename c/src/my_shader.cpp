#include "my_shader.h"

Shader::Shader(const char* vertexPath, const char* fragmentPath) {
    // 打开顶点着色器、片段着色器文件
    std::ifstream vShaderFile(vertexPath);
    std::ifstream fShaderFile(fragmentPath);

    // 读取顶点着色器、片段着色器字符串流
    std::stringstream vShaderStream, fShaderStream;
    vShaderStream << vShaderFile.rdbuf();
    fShaderStream << fShaderFile.rdbuf();

    // 关闭文件
    vShaderFile.close();
    fShaderFile.close();

    // 将流转换为字符串
    std::string vertexCode = vShaderStream.str();
    std::string fragmentCode = fShaderStream.str();	
    // 将字符串转换为char指针
    const char* vShaderCode = vertexCode.c_str();
    const char * fShaderCode = fragmentCode.c_str();

    // 编译着色器

    // 顶点着色器
    unsigned int vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vShaderCode, NULL);
    glCompileShader(vertexShader);
    // 检查编译是否发生错误
    checkCompileErrors(vertexShader, "VERTEX");
    
    // 片段着色器
    unsigned int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fShaderCode, NULL);
    glCompileShader(fragmentShader);
    // 检查编译是否发生错误
    checkCompileErrors(fragmentShader, "FRAGMENT");
    

    // 链接着色器程序
    ID = glCreateProgram();
    glAttachShader(ID, vertexShader);
    glAttachShader(ID, fragmentShader);
    glLinkProgram(ID);
    // 检查链接是否发生错误
    checkCompileErrors(ID, "PROGRAM");

    // 删除着色器，因为已经链接到我们的程序中了，不再需要了
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
}

void Shader::checkCompileErrors(unsigned int shader, std::string type) {
    int success;
    char infoLog[512];
    if(type != "PROGRAM") {
        glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
        if(!success) {
            glGetShaderInfoLog(shader, 512, NULL, infoLog);
            if(type == "VERTEX")
                std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
            else if(type == "FRAGMENT") 
                std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
        }
    }
    else {
        glGetProgramiv(shader, GL_LINK_STATUS, &success);
        if(!success) {
            glGetProgramInfoLog(shader, 512, NULL, infoLog);
            std::cout << "ERROR::PROGRAM_LINKING_ERROR of type: " << type << "\n" << infoLog << "\n -- --------------------------------------------------- -- " << std::endl;
        }
    }
}