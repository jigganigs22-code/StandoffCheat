#import "esp.h"
#import "il2cpp_resolver.h"
#import "w2s.h"
#import "tracelog.h"
#import <time.h>

extern IL2CPPResolver* GetResolver();
static ESP s_esp;

static bool s_loggedMatch = false;
static bool s_loggedEmpty = true;

static Vector3 ReadVector3(void* obj, const Il2CppClass* klass, const char* field) {
    Vector3 out;
    auto* r = GetResolver();
    if (!r || !obj || !klass) return {};
    const Il2CppFieldInfo* f = il2cpp_class_get_field_from_name(klass, field);
    if (!f) return {};
    il2cpp_field_get_value(obj, f, &out);
    return out;
}

static float ReadFloat(void* obj, const Il2CppClass* klass, const char* field) {
    auto* r = GetResolver();
    if (!r || !obj || !klass) return 0;
    const Il2CppFieldInfo* f = il2cpp_class_get_field_from_name(klass, field);
    if (!f) return 0;
    float v = 0; il2cpp_field_get_value(obj, f, &v); return v;
}

static int ReadInt(void* obj, const Il2CppClass* klass, const char* field) {
    auto* r = GetResolver();
    if (!r || !obj || !klass) return 0;
    const Il2CppFieldInfo* f = il2cpp_class_get_field_from_name(klass, field);
    if (!f) return 0;
    int v = 0; il2cpp_field_get_value(obj, f, &v); return v;
}

static bool ReadBool(void* obj, const Il2CppClass* klass, const char* field) {
    auto* r = GetResolver();
    if (!r || !obj || !klass) return false;
    const Il2CppFieldInfo* f = il2cpp_class_get_field_from_name(klass, field);
    if (!f) return false;
    unsigned char v = 0; il2cpp_field_get_value(obj, f, &v); return v != 0;
}

static void* GetObjectField(void* obj, const Il2CppClass* klass, const char* field) {
    auto* r = GetResolver();
    if (!r || !obj || !klass) return nullptr;
    const Il2CppFieldInfo* f = il2cpp_class_get_field_from_name(klass, field);
    if (!f) return nullptr;
    Il2CppObject* v = nullptr; il2cpp_field_get_value(obj, f, &v); return v;
}

static Vector3 GetTransformPosition(void* transform) {
    auto* r = GetResolver();
    if (!r || !r->classes.Transform || !transform) return {};
    const Il2CppMethodInfo* m = il2cpp_class_get_method_from_name(r->classes.Transform, "get_position", 0);
    if (!m) return {};
    Il2CppObject* res = il2cpp_runtime_invoke(m, transform, nullptr, nullptr);
    if (!res) return {};
    return *(Vector3*)il2cpp_object_unbox(res);
}

static void* GetComponent(void* obj, const Il2CppClass* componentClass) {
    auto* r = GetResolver();
    if (!r || !obj || !componentClass || !r->classes.Component) return nullptr;
    const Il2CppMethodInfo* m = il2cpp_class_get_method_from_name(r->classes.Component, "GetComponent", 1);
    if (!m) return nullptr;
    Il2CppException* exc = nullptr;
    void* params[] = { (void*)componentClass };
    return (void*)il2cpp_runtime_invoke(m, obj, params, &exc);
}

static void* GetInsideComponent(void* component, const Il2CppClass* targetClass) {
    auto* r = GetResolver();
    if (!r || !component) return nullptr;
    const Il2CppMethodInfo* m = il2cpp_class_get_method_from_name(r->classes.Component, "GetComponent", 1);
    if (!m) return nullptr;
    void* params[] = { (void*)targetClass };
    return (void*)il2cpp_runtime_invoke(m, component, params, nullptr);
}

static Vector3 GetBonePosition(void* playerController) {
    auto* r = GetResolver();
    if (!r || !playerController) return {};

    void* biped = nullptr;
    if (r->classes.BipedMap) {
        biped = GetInsideComponent(playerController, r->classes.BipedMap);
        if (!biped && r->classes.PlayerCharacterView) {
            void* view = GetInsideComponent(playerController, r->classes.PlayerCharacterView);
            if (view) biped = GetInsideComponent(view, r->classes.BipedMap);
        }
    }

    Vector3 head;
    const char* headCandidates[] = {
        "headPosition", "HeadPosition", "_headWorldPosition",
        "headWorldPosition", "_headPos", "_head", "headBone",
        nullptr
    };

    if (biped) {
        for (int i = 0; headCandidates[i]; i++) {
            const Il2CppFieldInfo* f = il2cpp_class_get_field_from_name(r->classes.BipedMap, headCandidates[i]);
            if (!f) continue;
            il2cpp_field_get_value(biped, f, &head);
            if (head.x != 0 || head.y != 0 || head.z != 0) return head;
        }
        void* headBone = GetInsideComponent(biped, r->classes.Transform);
        if (headBone) {
            Vector3 pos = GetTransformPosition(headBone);
            if (pos.x != 0 || pos.y != 0 || pos.z != 0) return pos;
        }
    }
    return {};
}

void ESP::Initialize() {
    NSLog(@"[StandoffCheat] ESP initialized");
}

void ESP::Update() {
    if (!g_config.initialized) return;

    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    double now = (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
    if (now - m_lastCollect < 0.2) return;
    m_lastCollect = now;

    CollectPlayers();
}

static void* GetAllPlayers() {
    auto* r = GetResolver();
    if (!r || !r->classes.PlayerController || !r->classes.Object) return nullptr;
    const Il2CppMethodInfo* m = il2cpp_class_get_method_from_name(
        r->classes.Object, "FindObjectsOfType", 1);
    if (m) {
        const Il2CppType* t = il2cpp_class_get_type(r->classes.PlayerController);
        Il2CppObject* typeObj = il2cpp_type_get_object(t);
        if (!typeObj) return nullptr;
        void* params[] = { typeObj };
        Il2CppException* exc = nullptr;
        return (void*)il2cpp_runtime_invoke(m, nullptr, params, &exc);
    }
    return nullptr;
}

void ESP::CollectPlayers() {
    std::vector<PlayerData> collected;
    collected.reserve(16);

    auto* r = GetResolver();
    if (!r) return;

    void* camera = nullptr;
    if (r->classes.Camera) {
        const Il2CppMethodInfo* getMain = il2cpp_class_get_method_from_name(r->classes.Camera, "get_main", 0);
        if (getMain) {
            Il2CppException* exc = nullptr;
            camera = (void*)il2cpp_runtime_invoke(getMain, nullptr, nullptr, &exc);
        }
    }
    if (!camera) return;
    g_mainCamera = camera;

    Vector3 localPos = {0,0,0};
    void* cameraTransform = GetInsideComponent(camera, r->classes.Transform);
    if (cameraTransform) localPos = GetTransformPosition(cameraTransform);

    Il2CppArray* allPlayers = (Il2CppArray*)GetAllPlayers();
    if (!allPlayers) {
        return;
    }

    uintptr_t count = il2cpp_array_length(allPlayers);
    if (count > 64) count = 64;

    for (uintptr_t i = 0; i < count; i++) {
        void* player = il2cpp_array_get(allPlayers, i);
        if (!player) continue;

        PlayerData pd = {};
        pd.obj = player;

        void* transform = GetInsideComponent(player, r->classes.Transform);
        if (transform) pd.position = GetTransformPosition(transform);

        Vector3 head = GetBonePosition(player);
        if (head.x != 0 || head.y != 0 || head.z != 0) {
            pd.headPosition = head;
        } else {
            pd.headPosition = pd.position;
            pd.headPosition.y += 1.7f;
        }

        pd.health = 100;
        pd.maxHealth = 100;
        const char* hpFields[] = {"_hp", "_health", "health", "Health", "_currentHp", "hp", nullptr};
        for (int f = 0; hpFields[f]; f++) {
            float v = ReadFloat(player, r->classes.PlayerController, hpFields[f]);
            if (v > 0) { pd.health = v; break; }
        }
        const char* mhpFields[] = {"_maxHp", "_maxHealth", "maxHealth", "MaxHealth", nullptr};
        for (int f = 0; mhpFields[f]; f++) {
            float v = ReadFloat(player, r->classes.PlayerController, mhpFields[f]);
            if (v > 0) { pd.maxHealth = v; break; }
        }
        if (pd.maxHealth <= 0) pd.maxHealth = 100;

        pd.team = 0;
        int teamReads = 0;
        const char* teamFields[] = {"_team", "team", "Team", "playerTeam", "_teamId", "TeamId", nullptr};
        for (int f = 0; teamFields[f]; f++) {
            const Il2CppFieldInfo* fi = il2cpp_class_get_field_from_name(r->classes.PlayerController, teamFields[f]);
            if (!fi) continue;
            teamReads++;
            int v = 0;
            il2cpp_field_get_value(player, fi, &v);
            if (v != 0) { pd.team = v; break; }
        }

        pd.alive = true;
        const char* aliveFields[] = {"_alive", "isAlive", "IsAlive", "_isAlive", "alive", nullptr};
        for (int f = 0; aliveFields[f]; f++) {
            if (il2cpp_class_get_field_from_name(r->classes.PlayerController, aliveFields[f])) {
                pd.alive = ReadBool(player, r->classes.PlayerController, aliveFields[f]);
                break;
            }
        }

        Vector3 diff = pd.position - localPos;
        pd.distance = sqrtf(diff.x*diff.x + diff.y*diff.y + diff.z*diff.z);

        pd.espColor = pd.team == 2 ? Color::Blue() : Color::Red();
        pd.isLocal = pd.team == 0 && pd.distance < 0.3f;

        collected.push_back(pd);
    }

    float nearestDist = 1e9f;
    size_t nearestIdx = SIZE_MAX;
    for (size_t i = 0; i < collected.size(); i++) {
        if (collected[i].distance < nearestDist) {
            nearestDist = collected[i].distance;
            nearestIdx = i;
        }
    }
    if (nearestIdx != SIZE_MAX) {
        collected[nearestIdx].isLocal = true;
        g_localPlayer = collected[nearestIdx].obj;
    }

    std::lock_guard<std::recursive_mutex> lock(g_playersMutex);
    g_players.swap(collected);

    if (!g_players.empty() && !s_loggedMatch) {
        CHEAT_LOG("e: first match — %zu players", g_players.size());
        s_loggedMatch = true;
        s_loggedEmpty = false;
    } else if (g_players.empty() && !s_loggedEmpty) {
        CHEAT_LOG("e: scan returned empty");
        s_loggedEmpty = true;
    }
}

void ESP::Render(CGContextRef ctx, CGFloat width, CGFloat height) {
    if (!g_config.initialized || !g_config.espEnabled || !ctx) return;

    m_screenWidth = width;
    m_screenHeight = height;

    std::vector<PlayerData> snapshot;
    {
        std::lock_guard<std::recursive_mutex> lock(g_playersMutex);
        snapshot = g_players;
    }

    CGFloat thickness = 1.5f;

    for (auto& player : snapshot) {
        if (player.isLocal || !player.alive) continue;

        Vector2 screen;
        float dist = 0;
        Vector3 ws = WorldToScreenPoint(g_mainCamera, player.position);
        dist = ws.z;
        if (ws.z <= 0) continue;
        screen.x = ws.x;
        screen.y = m_screenHeight - ws.y;
        if (screen.x <= 0 || screen.y <= 0 || screen.x >= width || screen.y >= height) continue;

        Color col = g_config.espTeamColor ? player.espColor : Color::Yellow();

        float boxH = 90.0f / (dist / 10.0f);
        if (boxH < 10) boxH = 10;
        if (boxH > height * 0.8f) boxH = height * 0.8f;
        float boxW = boxH * 0.6f;

        if (g_config.espBoxes) DrawBox(ctx, screen, boxW, boxH, col, thickness);

        if (g_config.espHealthBars) {
            DrawHealthBar(ctx, {screen.x - boxW/2 - 6, screen.y - boxH/2}, boxH, player.health, player.maxHealth);
        }

        if (g_config.espNames && strlen(player.name) > 0) {
            DrawText(ctx, player.name, screen.x, screen.y - boxH/2 - 14, col, 1.1f);
        }

        if (g_config.espDistance) {
            char buf[32];
            snprintf(buf, sizeof(buf), "%dm", (int)dist);
            DrawText(ctx, buf, screen.x, screen.y + boxH/2 + 10, Color::White(), 0.9f);
        }

        if (g_config.espSnaplines) {
            DrawSnapline(ctx, {screen.x, screen.y + boxH/2}, col);
        }
    }

    if (g_config.aimbotEnabled && g_config.aimbotShowFov && g_config.aimbotFov > 0) {
        DrawCircle(ctx, width/2, height/2, g_config.aimbotFov, Color::Yellow(), 1.0f);
    }
}

bool ESP::WorldToScreen(Vector3 world, Vector2& screen, float& distance) {
    if (!g_mainCamera) return false;
    Vector3 ws = WorldToScreenPoint(g_mainCamera, world);
    distance = ws.z;
    if (ws.z <= 0) return false;
    screen.x = ws.x;
    screen.y = m_screenHeight - ws.y;
    return true;
}

void ESP::DrawBox(CGContextRef ctx, Vector2 center, float w, float h, Color color, float thickness) {
    CGFloat x1 = center.x - w/2, y1 = center.y - h/2;
    CGFloat x2 = center.x + w/2, y2 = center.y + h/2;

    CGContextSetRGBStrokeColor(ctx, color.r, color.g, color.b, color.a);
    CGContextSetLineWidth(ctx, thickness);

    CGFloat cornerSize = w * 0.28f;
    if (cornerSize > 12) cornerSize = 12;

    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, x1, y1 + cornerSize);
    CGContextAddLineToPoint(ctx, x1, y1);
    CGContextAddLineToPoint(ctx, x1 + cornerSize, y1);

    CGContextMoveToPoint(ctx, x2 - cornerSize, y1);
    CGContextAddLineToPoint(ctx, x2, y1);
    CGContextAddLineToPoint(ctx, x2, y1 + cornerSize);

    CGContextMoveToPoint(ctx, x2, y2 - cornerSize);
    CGContextAddLineToPoint(ctx, x2, y2);
    CGContextAddLineToPoint(ctx, x2 - cornerSize, y2);

    CGContextMoveToPoint(ctx, x1 + cornerSize, y2);
    CGContextAddLineToPoint(ctx, x1, y2);
    CGContextAddLineToPoint(ctx, x1, y2 - cornerSize);
    CGContextStrokePath(ctx);

    if (color.a >= 0.2f) {
        CGContextSetRGBFillColor(ctx, color.r, color.g, color.b, 0.2f * color.a);
        CGContextFillRect(ctx, CGRectMake(x1, y1, w, h));
    }
}

void ESP::DrawHealthBar(CGContextRef ctx, Vector2 pos, float height, float health, float maxHealth) {
    float pct = maxHealth > 0 ? health / maxHealth : 0;
    if (pct < 0) pct = 0;
    if (pct > 1) pct = 1;

    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.55);
    CGContextFillRect(ctx, CGRectMake(pos.x, pos.y, 4, height));

    float barH = height * pct;
    float r, g;
    if (pct > 0.6f) { r = 0; g = 1; }
    else if (pct > 0.3f) { r = 1; g = 1; }
    else { r = 1; g = 0; }

    CGContextSetRGBFillColor(ctx, r, g, 0, 1);
    CGContextFillRect(ctx, CGRectMake(pos.x, pos.y + height - barH, 4, barH));

    CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.7);
    CGContextSetLineWidth(ctx, 0.5);
    CGContextStrokeRect(ctx, CGRectMake(pos.x, pos.y, 4, height));
}

void ESP::DrawText(CGContextRef ctx, const char* text, float x, float y, Color color, float scale) {
    if (!text || strlen(text) == 0) return;
    NSString* str = [NSString stringWithUTF8String:text];
    NSDictionary* attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:11 * scale],
        NSForegroundColorAttributeName: [UIColor colorWithRed:color.r green:color.g blue:color.b alpha:color.a],
        NSStrokeColorAttributeName: [UIColor blackColor],
        NSStrokeWidthAttributeName: @-2.0f
    };
    CGSize size = [str sizeWithAttributes:attrs];
    CGPoint point = {x - size.width/2, y};
    [str drawAtPoint:point withAttributes:attrs];
}

void ESP::DrawLine(CGContextRef ctx, float x1, float y1, float x2, float y2, Color color, float thickness) {
    CGContextSetRGBStrokeColor(ctx, color.r, color.g, color.b, color.a);
    CGContextSetLineWidth(ctx, thickness);
    CGContextMoveToPoint(ctx, x1, y1);
    CGContextAddLineToPoint(ctx, x2, y2);
    CGContextStrokePath(ctx);
}

void ESP::DrawCircle(CGContextRef ctx, float cx, float cy, float radius, Color color, float thickness) {
    CGContextSetRGBStrokeColor(ctx, color.r, color.g, color.b, color.a);
    CGContextSetLineWidth(ctx, thickness);
    CGContextAddArc(ctx, cx, cy, radius, 0, 2 * M_PI, 0);
    CGContextStrokePath(ctx);
}

void ESP::DrawSnapline(CGContextRef ctx, Vector2 bottom, Color color) {
    CGContextSetRGBStrokeColor(ctx, color.r, color.g, color.b, 0.6f);
    CGContextSetLineWidth(ctx, 1.0f);
    CGContextMoveToPoint(ctx, m_screenWidth/2, m_screenHeight);
    CGContextAddLineToPoint(ctx, bottom.x, bottom.y);
    CGContextStrokePath(ctx);
}

ESP* GetESP() {
    return &s_esp;
}