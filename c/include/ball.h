#ifndef __BALL_H__
#define __BALL_H__

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include <vector>
#include <cmath>

#define PI 3.14159265358979323846f
// 将球横纵划分成网格
#define Y_SEGMENTS 100
#define X_SEGMENTS 200


class Ball {
private:
	unsigned int VAO;				// 绑定的VAO序号
	int numVertices;			    // 模型顶点数
	std::vector<float> vertices;    // 顶点坐标（x，y，z）
	std::vector<float> texCoords;   // 纹理坐标（u，v）
	std::vector<float> normalVecs;  // 顶点法向量：用于判断顶点所构成的面的朝向
	std::vector<int> indices;		// 顶点索引
	float r;
	glm::vec3 center;
public:
	Ball() { numVertices = 0; }
	void setR(float rr);
	void bindVAO();
	void render();
	void setPos(glm::vec3 pos) { center = pos; }
	void movePos(glm::vec3 dpos) { center += dpos; };

	unsigned int getVAO() { return VAO; }
	int getNumVertices() { return numVertices; }
	std::vector<float> getVertices() { return vertices; }
	std::vector<float> getTextureCoords() { return texCoords; }
	std::vector<float> getNormals() { return normalVecs; }
	std::vector<int> getIndices() { return indices; }
	float getR() { return r; }
	glm::vec3 getPos() { return center; }
	glm::vec3 getCenter() { return center; }
};

# endif