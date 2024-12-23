#include "ball.h"
#include "utils.h"

#include <glad/glad.h>
#include <algorithm>

extern glm::vec3 cameraPos;
extern glm::vec3 cameraFront;
extern glm::vec3 cameraUp;

void Ball::setR(float rr) {
    r = rr;

    // 生成球的顶点
    for(int y = 0; y <= Y_SEGMENTS; y++) {
        for(int x = 0; x <= X_SEGMENTS; x++) {
            float xSegment = (float)x / (float)X_SEGMENTS;
            float ySegment = (float)y / (float)Y_SEGMENTS;
            float xPos = std::cos(xSegment * 2.0f * PI) * std::sin(ySegment * PI);
            float yPos = std::sin(xSegment * 2.0f * PI) * std::sin(ySegment * PI);
            float zPos = -std::cos(ySegment * PI);
            // 压入顶点坐标
            vertices.push_back(xPos);
            vertices.push_back(yPos);
            vertices.push_back(zPos);
            // 压入纹理坐标
            texCoords.push_back(xSegment);
            texCoords.push_back(ySegment);
            // 压入法向量(半径为1，则长度为1)
            normalVecs.push_back(xPos);
            normalVecs.push_back(yPos);
            normalVecs.push_back(zPos);
        }
    }

    // 生成球的Indices
    for(int i = 0; i < Y_SEGMENTS; i++) {
        for(int j = 0; j < X_SEGMENTS; j++) {
            indices.push_back(i * (X_SEGMENTS + 1) + j);
            indices.push_back((i + 1) * (X_SEGMENTS + 1) + j);
            indices.push_back((i + 1) * (X_SEGMENTS + 1) + j + 1);
            indices.push_back(i * (X_SEGMENTS + 1) + j);
            indices.push_back((i + 1) * (X_SEGMENTS + 1) + j + 1);
            indices.push_back(i * (X_SEGMENTS + 1) + j + 1);
        }
    }

    numVertices = vertices.size() / 3;
    
    bindVAO();
}

void Ball::bindVAO() {
    unsigned int VBO[3], EBO;
	glGenVertexArrays(1, &VAO);
    glGenBuffers(3, VBO);
    glGenBuffers(1, &EBO);

	setVAOVBOEBO(VAO, VBO, EBO, vertices, texCoords, normalVecs, indices, true);
}

void Ball::render() {

}