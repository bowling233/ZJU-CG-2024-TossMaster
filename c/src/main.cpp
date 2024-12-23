#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include <iostream>
#include <vector>

#include "utils.h"
#include "my_shader.h"
#include "obj_model.h"
#include "ball.h"
#include "game.h"

#define SCR_WIDTH 1500
#define SCR_HEIGHT 1500
#define CAR 0

void init(GLFWwindow* &window, int width, int height, std::string name);
void processInput(GLFWwindow *window);	// 处理按键操作
void key_callback(GLFWwindow* window, int key, int scancode, int action, int mode);	// 处理按键操作
void framebuffer_size_callback(GLFWwindow *window, int width, int height);	// 处理用户调整窗口
void mouse_callback(GLFWwindow* window, double xpos, double ypos);	// 处理光标移动


// 相机
glm::vec3 cameraPos   = glm::vec3(0.0f, 0.0f,  10.0f);
glm::vec3 cameraFront = glm::vec3(0.0f, 0.0f,  -1.0f);
glm::vec3 cameraUp    = glm::vec3(0.0f, 1.0f,  0.0f);

// 光标
bool firstMouse = true;
float yaw   = -90.0f; // 偏航角初始化为-90.0度，因为0.0时会导致方向向量指向右侧
float pitch =  0.0f;
float lastX =  800.0f / 2.0;
float lastY =  600.0 / 2.0;
float fov   =  45.0f;

// 时间
float deltaTime = 0.0f;
float lastFrame = 0.0f;

Game tossMaster(SCR_WIDTH, SCR_HEIGHT, "TossMaster");

int main() {
	GLFWwindow* window;
	try {
		init(window, tossMaster.getW(), tossMaster.getH(), tossMaster.getName());
	} catch(...) {
		return -1;
	}

	tossMaster.init();
	
	// 渲染
	while(!glfwWindowShouldClose(window)) {
		float t = (float)glfwGetTime();
		deltaTime = t - lastFrame;
        lastFrame = t;

		processInput(window);

		// //deltaTime = 0.001f;
        // // Manage user input
        // Breakout.processInput(deltaTime);

        // 更新游戏数据
        tossMaster.update(deltaTime);

		// 背景色
		glClearColor(0.0f, 0.1f, 0.25f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); // also clear the depth buffer now!

		tossMaster.render();

		// 交换缓冲并且检查是否有触发事件(比如键盘输入、鼠标移动)
		glfwSwapBuffers(window);
		glfwPollEvents();
	}
	tossMaster.engine->print();

	// 释放资源
	tossMaster.clear();

	glfwTerminate();

	return 0;
}


void init(GLFWwindow* &window, int width, int height, std::string name) {
	glfwInit();
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);	// 禁止用户调整窗口大小

#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE); // 为了兼容macOS
#endif

	// 创建glfw窗口
	window = glfwCreateWindow(width, height, name.c_str(), NULL, NULL);
	if (window == NULL) {
		std::cout << "Failed to create GLFW window" << std::endl;
		glfwTerminate();
		throw -1;
	}
	glfwMakeContextCurrent(window);
	glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);	// 注册回调函数
	glfwSetCursorPosCallback(window, mouse_callback);	// 注册回调函数
	glfwSetKeyCallback(window, key_callback);

	// 让GLFW监听鼠标运动
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);

	// 加载OpenGL所有函数指针
	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
		std::cout << "Failed to initialize GLAD" << std::endl;
		throw -1;
	}

	glEnable(GL_DEPTH_TEST);	// 开启深度测试
}

void processInput(GLFWwindow *window) {
    if(glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);

    float cameraSpeed = static_cast<float>(2.5 * deltaTime);
    if(glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
        cameraPos += cameraSpeed * cameraFront;
    if(glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
        cameraPos -= cameraSpeed * cameraFront;
    if(glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
        cameraPos -= glm::normalize(glm::cross(cameraFront, cameraUp)) * cameraSpeed;
    if(glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
        cameraPos += glm::normalize(glm::cross(cameraFront, cameraUp)) * cameraSpeed;
	if(glfwGetKey(window, GLFW_KEY_Z) == GLFW_PRESS)
    	tossMaster.engine->incVelocity(10 * deltaTime);
}

void key_callback(GLFWwindow* window, int key, int scancode, int action, int mode) {
	if(glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);

    if (key >= 0 && key < 1024) {
        if(action == GLFW_PRESS) {
			tossMaster.setKey(key, true);
			if(key == GLFW_KEY_Z) tossMaster.setState(GAME_PRE);
		}
        else if (action == GLFW_RELEASE) {
			tossMaster.setKey(key, false);
			if(key == GLFW_KEY_Z && tossMaster.getState() == GAME_PRE) tossMaster.setState(GAME_ACTIVE);
		}
	}
}

void framebuffer_size_callback(GLFWwindow *window, int width, int height) {
	glViewport(0, 0, width, height);
}

void mouse_callback(GLFWwindow* window, double xposIn, double yposIn) {
    float xpos = static_cast<float>(xposIn);
    float ypos = static_cast<float>(yposIn);

    if(firstMouse) {
        lastX = xpos;
        lastY = ypos;
        firstMouse = false;
    }

    float xoffset = xpos - lastX;
    float yoffset = lastY - ypos; // reversed since y-coordinates go from bottom to top
    lastX = xpos;
    lastY = ypos;

    float sensitivity = 0.05f; // change this value to your liking
    xoffset *= sensitivity;
    yoffset *= sensitivity;

    yaw += xoffset;
    pitch += yoffset;

    // make sure that when pitch is out of bounds, screen doesn't get flipped
    if(pitch > 89.0f) pitch = 89.0f;
    if(pitch < -89.0f) pitch = -89.0f;

    glm::vec3 front;
    front.x = cos(glm::radians(yaw)) * cos(glm::radians(pitch));
    front.y = sin(glm::radians(pitch));
    front.z = sin(glm::radians(yaw)) * cos(glm::radians(pitch));
    cameraFront = glm::normalize(front);
}