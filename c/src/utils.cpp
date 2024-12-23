#include "utils.h"
#include <ctime>

void setVAOVBO(unsigned int VAO, unsigned int VBO[], std::vector<float> vertices, std::vector<float> texCoords, std::vector<float> normalVecs, bool pro) {	
	// 首先绑定顶点数组对象，然后绑定并设置顶点缓冲区，最后配置顶点属性。
    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO[0]);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), &vertices[0], GL_STATIC_DRAW);
	// 位置属性，告诉OpenGL该如何解析顶点位置数据
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

	if(pro) {
		glBindBuffer(GL_ARRAY_BUFFER, VBO[1]);
		glBufferData(GL_ARRAY_BUFFER, texCoords.size() * sizeof(float), &texCoords[0], GL_STATIC_DRAW);
		// 纹理坐标属性，告诉OpenGL该如何解析顶点纹理坐标数据
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), (void*)0);
    	glEnableVertexAttribArray(1);

		glBindBuffer(GL_ARRAY_BUFFER, VBO[2]);
		glBufferData(GL_ARRAY_BUFFER, normalVecs.size() * sizeof(float), &normalVecs[0], GL_STATIC_DRAW);
		// 法向量属性，告诉OpenGL该如何解析顶点法向量数据
		glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), (void*)0);
    	glEnableVertexAttribArray(2);
	}
}

void setVAOVBOEBO(unsigned int VAO, unsigned int VBO[], unsigned int EBO, std::vector<float> vertices, std::vector<float> texCoords, std::vector<float> normalVecs, std::vector<int> indices, bool pro) {
	setVAOVBO(VAO, VBO, vertices, texCoords, normalVecs, pro);
	// 绑定EBO
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(int), &indices[0], GL_STATIC_DRAW);
}

void swap(float *a, int i, int j) {
    float temp = a[i];
    a[i] = a[j];
    a[j] = temp;
}
    
int qsort(float *a, int begin, int end) {
	int i, j, temp;
	i = begin - 1;
	j = begin;
	while(j < end) {
		if(a[j] <= a[end - 1]) swap(a, ++i, j);
		j++;
	}
	
	return i;
}

void randqsort(float *a, int begin, int n) {
    while(begin >= n) return;
    srand(static_cast<unsigned int>(time(0)));
    int key = begin + rand() % (n - begin);
    swap(a, key, n - 1);
    int m = qsort(a, begin, n);
    randqsort(a, begin, m);
    randqsort(a, m + 1, n);
}