#ifndef __GAME_H__
#define __GAME_H__

#include <string>
#include <map>

#include "my_shader.h"
#include "my_texture.h"
#include "physics_engine.h"


// 代表了游戏的当前状态
enum GameState {
    GAME_MENU,
    GAME_PRE,
    GAME_ACTIVE,
    GAME_WIN
}; 

class Game{
private:
    std::string name;
    GameState state;            // 游戏状态
    bool keys[1024];            // 游戏按键
    int width;
    int height;
    std::map<std::string, Shader> shaders;
    std::map<std::string, Texture2D> textures;
public:
	PhysicsEngine* engine;      // 物理引擎
    Game(int w, int h, std::string nn);

    void setKey(int key, bool istrue) { keys[key] = istrue; }
    void setState(GameState s) { state = s; }
    int getW() { return width; }
    int getH() { return height; }
    std::string getName() { return name; }
    GameState getState() { return state; }

    void init();                // 初始化游戏状态（加载所有的着色器/纹理/关卡）
    void processInput(float dt);// 按键处理
    void update(float dt);      // 更新物体状态
    void render();              // 渲染
    void clear();               // 释放着色器、纹理资源
};

#endif