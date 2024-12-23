#ifndef __MY_SHADER_H__
#define __MY_SHADER_H__

#include <glad/glad.h>
#include <glm/glm.hpp>

#include <string>
#include <fstream>
#include <sstream>
#include <iostream>

class Shader {
public:
    unsigned int ID;
    Shader() {};
    Shader(const char* vertexPath, const char* fragmentPath);
    void use() const { glUseProgram(ID); }
    void setMat4(const std::string &name, const glm::mat4 &mat) const {
        glUniformMatrix4fv(glGetUniformLocation(ID, name.c_str()), 1, GL_FALSE, &mat[0][0]);
    }
    void setVec3(const std::string &name, const glm::vec3 &vec) const { 
        glUniform3fv(glGetUniformLocation(ID, name.c_str()), 1, &vec[0]); 
    }

private:
    void checkCompileErrors(unsigned int shader, std::string type);
};

#endif