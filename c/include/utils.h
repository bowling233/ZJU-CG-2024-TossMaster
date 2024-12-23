#pragma once
#ifndef __UTILS_H__
#define __UTILS_H__

#include <iostream>
#include <vector>
#include <string>

#include <glad/glad.h>
#include <GLFW/glfw3.h>

struct vec3 {
    float x;
    float y;
    float z;
};

void setVAOVBOEBO(unsigned int VAO, unsigned int VBO[], unsigned int EBO, std::vector<float> vertices, std::vector<float> texCoords, std::vector<float> normalVecs,std::vector<int> indices, bool pro=false);
void setVAOVBO(unsigned int VAO, unsigned int VBO[], std::vector<float> vertices, std::vector<float> texCoords, std::vector<float> normalVecs, bool pro=false);
void swap(float *a, int i, int j);
int qsort(float *a, int begin, int end);
void randqsort(float *a, int begin, int n);

#endif