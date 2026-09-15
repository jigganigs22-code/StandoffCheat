#import "aimbot.h"
#import "il2cpp_resolver.h"
#import "w2s.h"

extern IL2CPPResolver* GetResolver();
extern void* g_mainCamera;
static Aimbot s_aimbot;

static Vector3 QuaternionEuler(float pitch, float yaw) {
    float cy = cosf(yaw * 0.5f), sy = sinf(yaw * 0.5f);
    float cp = cosf(pitch * 0.5f), sp = sinf(pitch * 0.5f);
    Quaternion q = { sp*cy, cp*sy, -sp*sy, cp*cy };
    Vector3 eul;
    float sinp = 2.0f * (q.w * q.x + q.y * q.z);
    if (fabsf(sinp) >= 1.0f) {
        float sign = sinp >= 0 ? 1 : -1;
        eul.x = M_PI / 2 * sign;
        eul.y = atan2f(q.y, q.w);
    } else {
        eul.x = asinf(sinp);
        eul.y = atan2f(2.0f * (q.w * q.y - q.z * q.x), 1.0f - 2.0f * (q.y*q.y + q.z*q.z));
    }
    eul.z = 0;
    return eul;
}

static Vector3 EulerAngles(const Quaternion& q) {
    float sinp = 2.0f * (q.w * q.x + q.y * q.z);
    Vector3 eul;
    if (fabsf(sinp) >= 1.0f) {
        float sign = sinp >= 0 ? 1 : -1;
        eul.x = M_PI / 2 * sign;
        eul.y = atan2f(q.y, q.w);
    } else {
        eul.x = asinf(sinp);
        eul.y = atan2f(2.0f * (q.w * q.y - q.z * q.x), 1.0f - 2.0f * (q.y*q.y + q.z*q.z));
    }
    eul.z = atan2f(2.0f * (q.w * q.z + q.x * q.y), 1.0f - 2.0f * (q.z*q.z + q.x*q.x));
    return eul;
}

static Quaternion QuaternionSlerp(const Quaternion& a, const Quaternion& b, float t) {
    float dot = a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w;
    if (dot < 0) { dot = -dot; }
    if (dot > 0.9995f) return a;
    float theta = acosf(dot);
    float sinT = sinf(theta);
    float wa = sinf((1-t)*theta)/sinT;
    float wb = sinf(t*theta)/sinT;
    return { a.x*wa + b.x*wb, a.y*wa + b.y*wb, a.z*wa + b.z*wb, a.w*wa + b.w*wb };
}

void* Aimbot::GetCameraTransform() {
    auto* r = GetResolver();
    if (!r || !g_mainCamera || !r->classes.Component || !r->classes.Transform) return nullptr;
    const Il2CppMethodInfo* getTransform = il2cpp_class_get_method_from_name(r->classes.Component, "get_transform", 0);
    if (!getTransform) return nullptr;
    return (void*)il2cpp_runtime_invoke(getTransform, g_mainCamera, nullptr, nullptr);
}

void Aimbot::Update() {
    if (!g_config.initialized || !g_config.aimbotEnabled || !m_players) return;

    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;

    PlayerData* target = FindBestTarget(screenW, screenH);
    if (!target) return;

    if (g_config.aimbotOnShoot) {
        Vector3 ws = WorldToScreenPoint(g_mainCamera, target->headPosition);
        if (ws.z <= 0) return;
        float sx = ws.x, sy = screenH - ws.y;
        float dx = sx - screenW/2, dy = sy - screenH/2;
        float screenDist = sqrtf(dx*dx + dy*dy);
        float assistRadius = g_config.aimbotFov * 0.35f;
        if (screenDist > assistRadius) return;
    }

    RotateCameraToward(target->headPosition, g_config.aimbotSmooth);
}

PlayerData* Aimbot::FindBestTarget(float screenW, float screenH) {
    PlayerData* best = nullptr;
    float bestAngle = g_config.aimbotFov;
    float centerX = screenW / 2, centerY = screenH / 2;

    if (!m_players) return nullptr;

    for (auto& p : *m_players) {
        if (p.isLocal || !p.alive) continue;

        Vector3 ws = WorldToScreenPoint(g_mainCamera, p.headPosition);
        if (ws.z <= 0) continue;

        float sx = ws.x;
        float sy = screenH - ws.y;
        float dx = sx - centerX, dy = sy - centerY;
        float angle = sqrtf(dx*dx + dy*dy);
        if (angle < bestAngle) {
            bestAngle = angle;
            best = &p;
        }
    }
    return best;
}

void Aimbot::RotateCameraToward(Vector3 target, float smooth) {
    auto* r = GetResolver();
    if (!r) return;

    void* camTransform = GetCameraTransform();
    if (!camTransform || !r->classes.Transform) return;

    Vector3 camPos = {0,0,0};
    const Il2CppMethodInfo* getPos = il2cpp_class_get_method_from_name(r->classes.Transform, "get_position", 0);
    if (getPos) {
        Il2CppObject* res = il2cpp_runtime_invoke(getPos, camTransform, nullptr, nullptr);
        if (res) camPos = *(Vector3*)il2cpp_object_unbox(res);
    }

    Vector3 dir = { target.x - camPos.x, target.y - camPos.y, target.z - camPos.z };
    float len = sqrtf(dir.x*dir.x + dir.y*dir.y + dir.z*dir.z);
    if (len < 0.01f) return;
    dir.x /= len; dir.y /= len; dir.z /= len;

    float yaw = atan2f(dir.x, dir.z);
    float pitch = -asinf(dir.y);

    Vector3 curEuler = {0,0,0};
    const Il2CppMethodInfo* getRot = il2cpp_class_get_method_from_name(r->classes.Transform, "get_rotation", 0);
    if (getRot) {
        Il2CppObject* res = il2cpp_runtime_invoke(getRot, camTransform, nullptr, nullptr);
        if (res) {
            Quaternion q = *(Quaternion*)il2cpp_object_unbox(res);
            curEuler = EulerAngles(q);
        }
    }

    float targetPitch = pitch * (180.0f / M_PI);
    float targetYaw = yaw * (180.0f / M_PI);

    float dYaw = targetYaw - curEuler.y;
    while (dYaw > 180) dYaw -= 360;
    while (dYaw < -180) dYaw += 360;

    float t = smooth > 0.01f ? (1.0f / smooth) : 1.0f;
    if (t > 1) t = 1;
    if (smooth > 8) t *= 0.5f;

    float newYaw = curEuler.y + dYaw * t;
    float newPitch = curEuler.x + (targetPitch - curEuler.x) * t;

    Quaternion targetQ;
    float cy = cosf(newYaw * 0.5f * M_PI / 180), sy = sinf(newYaw * 0.5f * M_PI / 180);
    float cp = cosf(newPitch * 0.5f * M_PI / 180), sp = sinf(newPitch * 0.5f * M_PI / 180);
    targetQ = { sp*cy, cp*sy, -sp*sy, cp*cy };

    const Il2CppMethodInfo* setRot = il2cpp_class_get_method_from_name(r->classes.Transform, "set_rotation", 1);
    if (!setRot) return;

    void* params[] = { &targetQ };
    il2cpp_runtime_invoke(setRot, camTransform, params, nullptr);
}

Aimbot* GetAimbot() {
    return &s_aimbot;
}