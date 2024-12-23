#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include "game.h"
#include "utils.h"

#include "obj_model.h"
#include "ball.h"

extern glm::vec3 cameraPos;
extern glm::vec3 cameraFront;
extern glm::vec3 cameraUp;

OBJBox box;
Ball ball;
OBJBall apple;

Game::Game(int w, int h, std::string nn): width(w), height(h), name(nn) {
    engine = new PhysicsEngine();
    state = GAME_MENU;
}

void Game::init() {
    // 创建着色器对象，并编译链接
    shaders["object"] = Shader("./shader/3d.vs", "./shader/3d_simple.fs");

	// 导入 OBJ 模型
	box.import("./model/box.obj");
    box.setPos(glm::vec3(0.0f, 0.0f, -2.0f));
    box.setScale(0.3f);
    std::cout << box.getHalfSize().x << std::endl;
    apple.import("./model/apple.obj");
    std::cout << apple.getR() << std::endl;

    // 设置 ball
    ball.setR(0.3f);

	// 设置纹理
    textures["box"] = Texture2D("./texture/box.png", GL_RGBA);
    textures["ball"] = Texture2D("./texture/2k_earth_daymap.jpg", GL_RGB);
    textures["apple"] = Texture2D("./texture/apple.jpg", GL_RGB);
}

void Game::processInput(float dt) {

}

void Game::update(float dt) {
    glm::vec3 rotationAxis = glm::cross(cameraFront, cameraUp);
    glm::mat4 rotationMatrix;

    if(state == GAME_MENU) {
        rotationMatrix = glm::rotate(glm::mat4(1.0), -PI/6, rotationAxis);
        glm::vec4 diff = rotationMatrix * glm::vec4(cameraFront, 1.0);
        glm::vec3 ballPos = cameraPos + glm::vec3(diff.x, diff.y, diff.z);
        ball.setPos(ballPos);
        apple.setPos(ballPos);
        if(engine->collide(ball, box)) state = GAME_WIN;
        if(engine->collide(apple, box)) state = GAME_WIN;
    }
    else if(state == GAME_PRE) {
        rotationMatrix = glm::rotate(glm::mat4(1.0), PI/6, rotationAxis);
        glm::vec4 dir = rotationMatrix * glm::vec4(cameraFront, 1.0);
        engine->setDir(dir.x, dir.y, dir.z);
    }
    else if(state == GAME_ACTIVE) {
        ball.movePos(engine->calMove(dt));
        apple.movePos(engine->calMove(dt));
        if(engine->collide(ball, box)) state = GAME_WIN;
        if(engine->collide(apple, box)) state = GAME_WIN;
    }
}

void Game::render() {
    // 投影矩阵
    glm::mat4 projection = glm::mat4(1.0f);
    projection = glm::perspective(glm::radians(45.0f), (float)width / (float)height, 0.1f, 100.0f);
    // 相机transformation
    glm::mat4 view = glm::lookAt(cameraPos, cameraPos + cameraFront, cameraUp);
    // model 矩阵
    glm::mat4 model = glm::mat4(1.0);

    // 激活object着色器
    shaders["object"].use();
    shaders["object"].setMat4("projection", projection);
    shaders["object"].setMat4("view", view);

    // 画 box
    model = glm::mat4(1.0);
    model = glm::translate(model, box.getPos());
    model = glm::scale(model, glm::vec3(box.getScale()));
    shaders["object"].setMat4("model", model);
    glBindTexture(GL_TEXTURE_2D, textures["box"].ID);	// 设置纹理采样器
    glBindVertexArray(box.getVAO());
    glDrawArrays(GL_TRIANGLES, 0, box.getNumVertices());

    // 画 ball
    model = glm::mat4(1.0);
    model = glm::translate(model, ball.getPos());
    model = glm::scale(model, glm::vec3(ball.getR()));
    shaders["object"].setMat4("model", model);
    glBindTexture(GL_TEXTURE_2D, textures["ball"].ID);	// 设置纹理采样器
    glBindVertexArray(ball.getVAO());
    glDrawElements(GL_TRIANGLES, ball.getNumVertices() * 6, GL_UNSIGNED_INT, 0);

    // 画apple
    model = glm::mat4(1.0);
    model = glm::translate(model, apple.getPos());
    model = glm::scale(model, glm::vec3(apple.getScale()));
    shaders["object"].setMat4("model", model);
    glBindTexture(GL_TEXTURE_2D, textures["apple"].ID);	// 设置纹理采样器
    glBindVertexArray(apple.getVAO());
    glDrawArrays(GL_TRIANGLES, 0, apple.getNumVertices());
}

void Game::clear() {
    for(auto it : shaders)
        glDeleteProgram(it.second.ID);
    for (auto it : textures)
        glDeleteTextures(1, &it.second.ID);
}