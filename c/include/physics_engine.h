#ifndef __PHYSICS_ENGINE_H__
#define __PHYSICS_ENGINE_H__

#include <vector>
#include <iostream>

#include "ball.h"
#include "obj_model.h"

class PhysicsEngine {
private:
	float v0;			// 物体初速度大小
	float x, y, z;		// 物理初始发射方向
	float vX, vY, vZ;	// 物体速度
	float gravity;		// 重力加速度(指向-y方向)
public:
	PhysicsEngine();

    void incVelocity(float dv) { v0 += dv;}
	void setDir(float dirX, float dirY, float dirZ);
	glm::vec3 calMove(float dt);
	bool collide(Ball &ball, OBJBox &box);
	bool collide(OBJBall &ball, OBJBox &box);

	void print() {
		std::cout << v0 << std::endl;
		std::cout << x << " " << y << " " << y << std::endl;
	}
};

#endif