#pragma once
#include <vector>
#include <cstring>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include <CoreGraphics/CoreGraphics.h>
#include <mach/mach.h>
#include <dispatch/dispatch.h>

struct Vector3 {
    float x, y, z;
    Vector3() : x(0), y(0), z(0) {}
    Vector3(float x, float y, float z) : x(x), y(y), z(z) {}
    float Distance(const Vector3& o) const {
        float dx = x - o.x, dy = y - o.y, dz = z - o.z;
        return sqrtf(dx*dx + dy*dy + dz*dz);
    }
    Vector3 operator-(const Vector3& o) const { return {x-o.x, y-o.y, z-o.z}; }
    Vector3 operator+(const Vector3& o) const { return {x+o.x, y+o.y, z+o.z}; }
    Vector3 operator*(float s) const { return {x*s, y*s, z*s}; }
};

struct Vector2 {
    float x, y;
    Vector2() : x(0), y(0) {}
    Vector2(float x, float y) : x(x), y(y) {}
};

struct Quaternion {
    float x, y, z, w;
};

struct Color {
    float r, g, b, a;
    Color() : r(1), g(1), b(1), a(1) {}
    Color(float r, float g, float b, float a) : r(r), g(g), b(b), a(a) {}
    static Color Red() { return {1, 0, 0, 1}; }
    static Color Green() { return {0, 1, 0, 1}; }
    static Color Blue() { return {0, 0.5f, 1, 1}; }
    static Color Yellow() { return {1, 1, 0, 1}; }
    static Color White() { return {1, 1, 1, 1}; }
    static Color Cyan() { return {0, 1, 1, 1}; }
    static Color Black() { return {0, 0, 0, 0.8f}; }
};

struct CheatConfig {
    bool espEnabled = true;
    bool espBoxes = true;
    bool espHealthBars = true;
    bool espNames = true;
    bool espSnaplines = true;
    bool espSkeleton = false;
    bool espDistance = true;
    bool espTeamColor = true;
    bool espWeapon = false;

    bool aimbotEnabled = false;
    bool aimbotOnShoot = true;
    bool aimbotOnAim = false;
    float aimbotFov = 90.0f;
    float aimbotSmooth = 5.0f;
    int aimbotBone = 0;
    bool aimbotVisCheck = true;
    bool aimbotShowFov = true;

    bool recoilEnabled = false;
    float recoilMultiplier = 0.0f;

    bool menuOpen = false;
    bool initialized = false;
};

struct PlayerData {
    void* obj;
    void* transform;
    Vector3 position;
    Vector3 headPosition;
    float health;
    float maxHealth;
    int team;
    bool alive;
    bool isLocal;
    char name[64];
    float distance;
    int weaponId;
    Color espColor;
};

extern CheatConfig g_config;
extern void* g_localPlayer;
extern void* g_mainCamera;
extern bool g_firingDetected;
extern std::vector<PlayerData> g_players;
extern std::recursive_mutex g_playersMutex;
