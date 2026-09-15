#pragma once
#import "cheat_data.h"
#import "il2cpp_resolver.h"

class Aimbot {
public:
    void Update();
    void SetPlayerList(std::vector<PlayerData>* players) { m_players = players; }

private:
    PlayerData* FindBestTarget(float screenW, float screenH);
    void RotateCameraToward(Vector3 target, float smooth);
    void* GetCameraTransform();

    std::vector<PlayerData>* m_players = nullptr;
};

Aimbot* GetAimbot();