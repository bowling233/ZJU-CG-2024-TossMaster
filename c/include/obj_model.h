#ifndef __OBJ_MODEL_H__
#define __OBJ_MODEL_H__

#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <sstream>

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

class OBJModel {
private:
    unsigned int VAO;				// 绑定的VAO序号
	int numVertices;			    // 模型顶点数
	std::vector<float> vertices;    // 顶点坐标（x，y，z）
	std::vector<float> texCoords;   // 纹理坐标（u，v）
	std::vector<float> normalVecs;  // 顶点法向量：用于判断顶点所构成的面的朝向
public:
	OBJModel() { numVertices = 0; }
	void import(const char* filePath);	// 导入obj文件
	void bindVAO();
	void render();
	void move2Origin(float dx, float dy, float dz);	// 在局部坐标系中，将OBJ模型整体平移为以原点为中心

	unsigned int getVAO() { return VAO; }
	int& getNumVertices() { return numVertices; }
	std::vector<float>& getVertices() { return vertices; }
	std::vector<float>& getTextureCoords() { return texCoords; }
	std::vector<float>& getNormals() { return normalVecs; }
};

class OBJBox: public OBJModel {
private:
	float scale;			// 对OBJ模型的缩放系数
	glm::vec3 center;		// 包围盒中心
	glm::vec3 halfSize;		// 包围盒的三个方向正半边长
	void calBox();			// 计算 OBJBox 的包围盒中心及对角线点
	void move2Origin();		// 在局部坐标系中，将OBJ模型整体平移为以原点为中心
public:
	OBJBox(): center(glm::vec3(0.0f)), scale(1.0f) {};
	void import(const char* filePath);
	void setPos(glm::vec3 pos) { center = pos; }
	void movePos(glm::vec3 dpos) { center += dpos; }
	void setScale(float s) { scale = s; halfSize *= glm::vec3(scale);}

	glm::vec3 getPos() { return center; }
	float getScale() { return scale; }
	glm::vec3 getCenter() { return center; }
	glm::vec3 getHalfSize() { return halfSize; }
};

class OBJBall: public OBJModel {
private:
	float scale;			// 对OBJ模型的缩放系数
	glm::vec3 center;		// 包围球中心
	float r;				// 包围球半径
	void calBall();    		// 计算 OBJBall 的包围球中心及半径
	void move2Origin();		// 在局部坐标系中，将OBJ模型整体平移为以原点为中心
public:
	OBJBall(): center(glm::vec3(0.0f)), scale(1.0f) {};
	void import(const char* filePath);
	void setPos(glm::vec3 pos) { center = pos; }
	void movePos(glm::vec3 dpos) { center += dpos; }
	void setScale(float s) { scale = s; r *= scale; }

	glm::vec3 getPos() { return center; }
	float getScale() { return scale; }
	glm::vec3 getCenter() { return center; }
	float getR() { return r; }
};

# endif