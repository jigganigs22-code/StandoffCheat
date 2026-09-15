#pragma once
#import "cheat_data.h"
#import "il2cpp_resolver.h"

class ESP {
public:
    void Initialize();
    void Update();
    void Render(CGBitmapContextRef ctx, CGFloat width, CGFloat height);

private:
    void CollectPlayers();
    bool WorldToScreen(Vector3 world, Vector2& screen, float& distance);
    void DrawBox(CGBitmapContextRef ctx, Vector2 center, float w, float h, Color color, float thickness);
    void DrawHealthBar(CGBitmapContextRef ctx, Vector2 pos, float height, float health, float maxHealth);
    void DrawText(CGBitmapContextRef ctx, const char* text, float x, float y, Color color, float scale = 1.0f);
    void DrawLine(CGBitmapContextRef ctx, float x1, float y1, float x2, float y2, Color color, float thickness);
    void DrawCircle(CGBitmapContextRef ctx, float cx, float cy, float radius, Color color, float thickness);
    void DrawSnapline(CGBitmapContextRef ctx, Vector2 bottom, Color color);

    CGFloat m_screenWidth = 0;
    CGFloat m_screenHeight = 0;
};

ESP* GetESP();
