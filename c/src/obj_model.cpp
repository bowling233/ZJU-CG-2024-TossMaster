#include "obj_model.h"
#include "utils.h"

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <algorithm>

void OBJModel::import(const char* filePath) {
	float x, y, z;
	std::string content, line, type;
	std::ifstream fileStream(filePath);
	std::vector<float> orig_vertices;	// 存储.obj文件中读取的原始顶点数据
	std::vector<float> orig_texCoords;	// 存储.obj文件中读取的原始纹理数据
	std::vector<float> orig_normalVecs;	// 存储.obj文件中读取的原始顶点法向量数据
	
	while (getline(fileStream, line)) {
		// 处理顶点数据
		if(line.substr(0, 2) == "v ") {
			std::istringstream iss(line.substr(2, line.size()-2)); // 跳过“v ”
			iss >> x >> y >> z;
			orig_vertices.push_back(x);
			orig_vertices.push_back(y);
			orig_vertices.push_back(z);
			numVertices++;
		}
		// 处理纹理数据
		else if(line.substr(0, 2) == "vt") {
			std::istringstream iss(line.substr(3, line.size()-3)); // 跳过“vt ”
			iss >> x >> y;
			orig_texCoords.push_back(x);
			orig_texCoords.push_back(y);
		}
		// 处理法向量数据
		else if(line.substr(0, 2) == "vn") {
			std::istringstream iss(line.substr(3, line.size()-3)); // 跳过“vn ”
			iss >> x >> y >> z;
			orig_normalVecs.push_back(x);
			orig_normalVecs.push_back(y);
			orig_normalVecs.push_back(z);
		}
		else if(line.substr(0, 2) == "f ") {
			int v[4], t[4], n[4];	// 一个面最多由4个点确定
			int cnt = 0;			// cnt用于记录一个面由几个点确定
			std::istringstream iss(line.substr(2, line.size()-2)); // 跳过“f ”
			std::string seg;
			while(iss >> seg) {
				int pos1, pos2, len;
				pos1 = seg.find('/');           // 找到第一个 '/' 的位置
				pos2 = seg.find('/', pos1 + 1); // 找到第二个 '/' 的位置
				len = seg.size();

				v[cnt] = std::stoi(seg.substr(0, pos1));
				if(pos2 == pos1 + 1) t[cnt] = -1;
				else t[cnt] = std::stoi(seg.substr(pos1 + 1, pos2 - pos1 - 1));
				n[cnt] = std::stoi(seg.substr(pos2 + 1, len - pos2 - 1));

				// 转换为 vector index
				v[cnt] = (v[cnt] - 1) * 3;
				if(t[cnt] != -1) t[cnt] = (t[cnt] - 1) * 2;
				n[cnt] = (n[cnt] - 1) * 3;

				cnt++;
				if(cnt == 4) break;	// 说明4个点都读取完毕，为防止段错误，直接break
			}

			// 若一个面由3个顶点确定，直接顺序存储3个点
			if(cnt == 3) {
				for(int i = 0; i < cnt; i++) {
					vertices.push_back(orig_vertices[v[i]]);
					vertices.push_back(orig_vertices[v[i]+1]);
					vertices.push_back(orig_vertices[v[i]+2]);
					if(t[i] != -1) {
						texCoords.push_back(orig_texCoords[t[i]]);
						texCoords.push_back(orig_texCoords[t[i]+1]);
					}
					else {
						texCoords.push_back(0.0f);
						texCoords.push_back(0.0f);
					}
					normalVecs.push_back(orig_normalVecs[n[i]]);
					normalVecs.push_back(orig_normalVecs[n[i]+1]);
					normalVecs.push_back(orig_normalVecs[n[i]+2]);
				}
			}
			// 若一个面由4个顶点确定，则拆分为2个三角形
			else if(cnt == 4) {
				for(int i = 0; i < 3; i++) { // 0, 1, 2
					vertices.push_back(orig_vertices[v[i]]);
					vertices.push_back(orig_vertices[v[i]+1]);
					vertices.push_back(orig_vertices[v[i]+2]);
					if(t[i] != -1) {
						texCoords.push_back(orig_texCoords[t[i]]);
						texCoords.push_back(orig_texCoords[t[i]+1]);
					}
					else {
						texCoords.push_back(0.0f);
						texCoords.push_back(0.0f);
					}
					normalVecs.push_back(orig_normalVecs[n[i]]);
					normalVecs.push_back(orig_normalVecs[n[i]+1]);
					normalVecs.push_back(orig_normalVecs[n[i]+2]);
				}
				for(int i = 2; i != 1; i = (i+1)%4) { // 2, 3, 0
					vertices.push_back(orig_vertices[v[i]]);
					vertices.push_back(orig_vertices[v[i]+1]);
					vertices.push_back(orig_vertices[v[i]+2]);
					if(t[i] != -1) {
						texCoords.push_back(orig_texCoords[t[i]]);
						texCoords.push_back(orig_texCoords[t[i]+1]);
					}
					else {
						texCoords.push_back(0.0f);
						texCoords.push_back(0.0f);
					}
					normalVecs.push_back(orig_normalVecs[n[i]]);
					normalVecs.push_back(orig_normalVecs[n[i]+1]);
					normalVecs.push_back(orig_normalVecs[n[i]+2]);
				}
			}
		}
	}
	numVertices = vertices.size() / 3;
	std::cout << "\033[33m[Success] Model has imported from " << filePath << "\033[0m" << std::endl;
}

void OBJModel::bindVAO() {
	unsigned int VBO[3];
	glGenVertexArrays(1, &VAO);
    glGenBuffers(3, VBO);

	setVAOVBO(VAO, VBO, vertices, texCoords, normalVecs, true);
}

void OBJModel::render() {
	
}

void OBJModel::move2Origin(float dx, float dy, float dz) {
	for(int i = 0; i < numVertices; i++) {
		vertices[3*i] += dx;
		vertices[3*i+1] += dy;
		vertices[3*i+2] += dz;
	}
}



void OBJBox::import(const char* filePath) {
	OBJModel::import(filePath);
	calBox();
	std::cout << center.x << " " << center.y << " " << center.z << std::endl;
	move2Origin();
	OBJModel::bindVAO();
	std::cout << halfSize.x << " " << halfSize.y << " " << halfSize.z << std::endl;
}

void OBJBox::calBox() {
	float x_max, x_min;
	float y_max, y_min;
	float z_max, z_min;
	float x_center, y_center, z_center;

	float v_num = getNumVertices();
	std::vector<float>& vertices = getVertices();
	std::vector<float> x, y, z;

    for (int i = 0; i < v_num; i++) {
        x.push_back(vertices[3*i]);
        y.push_back(vertices[3*i+1]);
        z.push_back(vertices[3*i+2]);
    }

	std::sort(x.begin(), x.end());
	std::sort(y.begin(), y.end());
	std::sort(z.begin(), z.end());
	
    x_max = x_min = y_max = y_min = z_max = z_min = 0.0f;

	//取最小10个数的平均作为最小值
    for (int i = 0; i < 10; i++) {
        x_min += x[i];
        y_min += y[i];
        z_min += z[i];
    }
    x_min /= 10; y_min /= 10; z_min /= 10;  

	//取最大10个数的平均作为最大值
    for (int i = v_num-10; i < v_num; i++) {
        x_max += x[i];
        y_max += y[i];
        z_max += z[i];
    }
    x_max /= 10; y_max /= 10; z_max /= 10;  
    
    x_center = (x_min + x_max) / 2.0f;
    y_center = (y_min + y_max) / 2.0f;
    z_center = (z_min + z_max) / 2.0f;

	center = glm::vec3(x_center, y_center, z_center);
    halfSize = glm::vec3((x_max-x_min)/2.0f, (y_max-y_min)/2.0f, (z_max-z_min)/2.0f);
}

void OBJBox::move2Origin() {
	OBJModel::move2Origin(-center.x, -center.y, -center.z);
	center = glm::vec3(0.0f);
}



void OBJBall::import(const char* filePath) {
	OBJModel::import(filePath);
	calBall();
	std::cout << center.x << " " << center.y << " " << center.z << std::endl;
	move2Origin();
	OBJModel::bindVAO();
	std::cout << r << std::endl;
}

/**
 * 包围球的球心是所有顶点的均值
 * 包围球的半径是距离球心最远的顶点的距离
 * （为排除孤点所带来的影响，取10个点进行平均）
 */
void OBJBall::calBall() {
	float x_center, y_center, z_center;
	float x_d, y_d, z_d;

	float v_num = getNumVertices();
	std::vector<float>& vertices = getVertices();
	
	x_center = y_center = z_center = 0.0f;
    for(int i = 0; i < v_num; i++) {
        x_center += vertices[3*i];
        y_center += vertices[3*i+1];
        z_center += vertices[3*i+2];
    }
	x_center /= v_num;
	y_center /= v_num;
	z_center /= v_num;
	center = glm::vec3(x_center, y_center, z_center);

	// 取最大距离的为半径
	r = 0.0f;
	for(int i = 0; i < v_num; i++) {
		x_d = (vertices[3*i]   - x_center) * (vertices[3*i]   - x_center);
		y_d = (vertices[3*i+1] - y_center) * (vertices[3*i+1] - y_center);
		z_d = (vertices[3*i+2] - z_center) * (vertices[3*i+2] - z_center);
        if((x_d+y_d+z_d) > r*r) {
			r = sqrt(x_d+y_d+z_d);
		}
    }


}

void OBJBall::move2Origin() {
	OBJModel::move2Origin(-center.x, -center.y, -center.z);
	center = glm::vec3(0.0f);
}