#include "physics_engine.h"

PhysicsEngine::PhysicsEngine() {
    v0 = 0.0f;
    gravity = 9.8f;
}

void PhysicsEngine::setDir(float dirX, float dirY, float dirZ) { 
    x = dirX;
    y = dirY;
    z = dirZ;
    vX = v0 * x;
    vY = v0 * y;
    vZ = v0 * z;
}

glm::vec3 PhysicsEngine::calMove(float dt) {
    float dx = vX * dt;
    float dy = vY * dt;
    float dz = vZ * dt;
    vY -= gravity * dt;

    return glm::vec3(dx, dy, dz);
}

// 纯球体与OBJBox碰撞
bool PhysicsEngine::collide(Ball &ball, OBJBox &box) {
    // 计算AABB的半边长范围
    glm::vec3 aabbHalfExtents = box.getHalfSize();

    // 计算两个中心的差向量
    glm::vec3 difference = ball.getCenter() - box.getCenter();
    
    // 计算clamped向量
    glm::vec3 clamped = glm::clamp(difference, -aabbHalfExtents, aabbHalfExtents);

    // 碰撞箱上距离球最近的点closest
    glm::vec3 closest = box.getCenter() + clamped;

    // 获得圆心center和最近点closest的向量并判断是否 length < radius
    difference = closest - ball.getCenter();

    return glm::length(difference) < ball.getR();
}

// OBJBall与OBJBox碰撞
bool PhysicsEngine::collide(OBJBall &ball, OBJBox &box) {
    // 计算AABB的半边长范围
    glm::vec3 aabbHalfExtents = box.getHalfSize();

    // 计算两个中心的差向量
    glm::vec3 difference = ball.getCenter() - box.getCenter();
    //std::cout << box.getCenter().x << " " << box.getCenter().y << " " << box.getCenter().z << std::endl;
    
    // 计算clamped向量
    glm::vec3 clamped = glm::clamp(difference, -aabbHalfExtents, aabbHalfExtents);

    // 碰撞箱上距离球最近的点closest
    glm::vec3 closest = box.getCenter() + clamped;

    // 获得圆心center和最近点closest的向量并判断是否 length < radius
    difference = closest - ball.getCenter();

    return glm::length(difference) < ball.getR();
}