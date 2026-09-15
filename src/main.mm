#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <pthread.h>
#import "cheat_data.h"
#import "menu.h"
#import "overlay.h"
#import "esp.h"
#import "aimbot.h"
#import "recoil.h"
#import "tracelog.h"

IL2CPPResolver* g_resolver = nullptr;
void* g_localPlayer = nullptr;
void* g_mainCamera = nullptr;
bool g_firingDetected = true;
std::vector<PlayerData> g_players;
std::recursive_mutex g_playersMutex;
CheatConfig g_config;

static bool g_hooked = false;
static void* g_fwHandle = NULL;
static bool g_bindingReady = false;

#pragma mark - Process guard

static BOOL IsRunningInStandoff() {
    NSString* bundleId = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleId isEqualToString:@"com.axlebolt.standoff2"] ||
           [[NSProcessInfo processInfo].processName isEqualToString:@"Standoff2"] ||
           [[NSProcessInfo processInfo].processName isEqualToString:@"UnityFramework"] ||
           [bundleId hasPrefix:@"com.axlebolt"];
}

#pragma mark - IL2CPP bootstrap

static void* LoadIL2CppFunctions() {
    NSString* fwPath = [[NSBundle mainBundle] pathForResource:@"UnityFramework" ofType:@"framework"];
    if (fwPath) {
        NSString* binPath = [fwPath stringByAppendingPathComponent:@"UnityFramework"];
        void* h = dlopen(binPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        if (h) return h;
    }
    void* handle = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOW | RTLD_GLOBAL);
    if (!handle) handle = dlopen("UnityFramework", RTLD_NOW | RTLD_GLOBAL);
    if (!handle) handle = dlopen(NULL, RTLD_LAZY);
    return handle;
}

static bool BindIL2CppFunctions(void* handle) {
    auto bind = [](void* h, const char* name) {
        void* ptr = dlsym(h, name);
        if (!ptr) ptr = dlsym(RTLD_DEFAULT, name);
        return ptr;
    };

    struct { const char* name; void** out; } binds[] = {
        {"il2cpp_domain_get", (void**)&il2cpp_domain_get},
        {"il2cpp_domain_get_assemblies", (void**)&il2cpp_domain_get_assemblies},
        {"il2cpp_assembly_get_image", (void**)&il2cpp_assembly_get_image},
        {"il2cpp_image_get_name", (void**)&il2cpp_image_get_name},
        {"il2cpp_class_from_name", (void**)&il2cpp_class_from_name},
        {"il2cpp_class_get_field_from_name", (void**)&il2cpp_class_get_field_from_name},
        {"il2cpp_class_get_method_from_name", (void**)&il2cpp_class_get_method_from_name},
        {"il2cpp_class_get_name", (void**)&il2cpp_class_get_name},
        {"il2cpp_class_get_namespace", (void**)&il2cpp_class_get_namespace},
        {"il2cpp_field_get_offset", (void**)&il2cpp_field_get_offset},
        {"il2cpp_field_get_name", (void**)&il2cpp_field_get_name},
        {"il2cpp_field_get_value", (void**)&il2cpp_field_get_value},
        {"il2cpp_field_set_value", (void**)&il2cpp_field_set_value},
        {"il2cpp_field_static_get_value", (void**)&il2cpp_field_static_get_value},
        {"il2cpp_field_static_set_value", (void**)&il2cpp_field_static_set_value},
        {"il2cpp_runtime_invoke", (void**)&il2cpp_runtime_invoke},
        {"il2cpp_runtime_invoke_varargs", (void**)&il2cpp_runtime_invoke_varargs},
        {"il2cpp_method_get_name", (void**)&il2cpp_method_get_name},
        {"il2cpp_object_new", (void**)&il2cpp_object_new},
        {"il2cpp_object_unbox", (void**)&il2cpp_object_unbox},
        {"il2cpp_object_get_class", (void**)&il2cpp_object_get_class},
        {"il2cpp_class_from_il2cpp_type", (void**)&il2cpp_class_from_il2cpp_type},
        {"il2cpp_class_get_type", (void**)&il2cpp_class_get_type},
        {"il2cpp_type_get_type", (void**)&il2cpp_type_get_type},
        {"il2cpp_type_get_object", (void**)&il2cpp_type_get_object},
        {"il2cpp_string_new", (void**)&il2cpp_string_new},
        {"il2cpp_string_length", (void**)&il2cpp_string_length},
        {"il2cpp_string_chars", (void**)&il2cpp_string_chars},
        {"il2cpp_array_new", (void**)&il2cpp_array_new},
        {"il2cpp_array_new_specific", (void**)&il2cpp_array_new_specific},
        {"il2cpp_array_class_get", (void**)&il2cpp_array_class_get},
        {"il2cpp_array_get", (void**)&il2cpp_array_get},
        {"il2cpp_array_length", (void**)&il2cpp_array_length},
        {"il2cpp_thread_attach", (void**)&il2cpp_thread_attach},
        {"il2cpp_thread_current", (void**)&il2cpp_thread_current},
        {"il2cpp_thread_get_domain", (void**)&il2cpp_thread_get_domain},
    };

    int resolved = 0;
    for (auto& b : binds) {
        void* p = bind(handle, b.name);
        if (p) { *b.out = p; resolved++; }
    }

    if (resolved < 20) {
        CHEAT_LOG("t: IL2CPP binding failed %d/%d", resolved, 36);
        return false;
    }
    CHEAT_LOG("t: IL2CPP API bound, %d symbols", resolved);
    return true;
}

static int g_domainRetries = 0;
static int g_resolverRetries = 0;

static void FinishInitialize() {
    CHEAT_LOG("m: FinishInitialize on main thread");
    if (g_hooked) return;

    if (!il2cpp_domain_get || !il2cpp_domain_get()) {
        CHEAT_LOG("m: domain not ready yet");
        if (g_domainRetries++ >= 120) { CHEAT_LOG("m: gave up waiting for domain"); return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)),
                       dispatch_get_main_queue(), ^{ FinishInitialize(); });
        return;
    }

    g_resolver = new IL2CPPResolver();
    if (!g_resolver->Initialize()) {
        CHEAT_LOG("m: resolver Initialize FAILED — will retry");
        delete g_resolver;
        g_resolver = nullptr;
        if (g_resolverRetries++ >= 60) { CHEAT_LOG("m: gave up on resolver"); return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1000 * NSEC_PER_MSEC)),
                       dispatch_get_main_queue(), ^{ FinishInitialize(); });
        return;
    }
    CHEAT_LOG("m: resolver ok — PlayerController=%p Transform=%p Camera=%p",
              (void*)g_resolver->classes.PlayerController,
              (void*)g_resolver->classes.Transform,
              (void*)g_resolver->classes.Camera);

    g_config.initialized = true;
    g_hooked = true;
    CHEAT_LOG("m: HOOKED — cheat active");
}

#pragma mark - Update loop (main thread, via overlay CADisplayLink)

void CheatUpdateMainThread() {
    if (!g_hooked || !g_config.initialized) return;
    @autoreleasepool {
        static long tick = 0;
        GetRecoilControl()->Update();

        ESP* esp = (ESP*)GetESP();
        esp->Update();

        if (g_config.aimbotEnabled && !g_players.empty()) {
            Aimbot* aim = GetAimbot();
            aim->SetPlayerList(&g_players);
            aim->Update();
        }

        if ((tick++ % 600) == 0) {
            CHEAT_LOG("m: alive tick=%ld players=%zu", tick, g_players.size());
        }
    }
}

#pragma mark - UI scheduling (main thread)

static void ScheduleUI() {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            CHEAT_LOG("m: creating UI");
            ShowMenu();
            SetupOverlayWindow();
            CHEAT_LOG("m: UI created");
        });
    });
}

#pragma mark - Init thread (background, quick retry)

static void* initThread(void* arg) {
    @autoreleasepool {
        CHEAT_LOG("t: init thread start");
        int attempts = 0;
        while (!g_bindingReady && attempts < 900) {
            if (!g_fwHandle) g_fwHandle = LoadIL2CppFunctions();
            if (g_fwHandle && BindIL2CppFunctions(g_fwHandle)) {
                g_bindingReady = true;
                CHEAT_LOG("t: bind success at attempt %d", attempts);
                dispatch_async(dispatch_get_main_queue(), ^{
                    FinishInitialize();
                });
                break;
            }
            usleep(100 * 1000);
            attempts++;
        }
        if (!g_bindingReady) CHEAT_LOG("t: gave up binding after %d attempts", attempts);
    }
    return NULL;
}

#pragma mark - Entry

__attribute__((constructor))
static void StandoffCheatInit() {
    if (!IsRunningInStandoff()) return;

    CHEAT_LOG_OPEN();
    CHEAT_INSTALL_CRASH_HANDLERS();
    CHEAT_LOG("init: starting — Standoff 2 cheat");

    pthread_t thread;
    pthread_create(&thread, NULL, initThread, NULL);
    ScheduleUI();
}

@interface StandoffCheatLoader : NSObject
@end

@implementation StandoffCheatLoader

+ (void)load {
    if (!IsRunningInStandoff()) return;
    CHEAT_LOG("init: loader attached");
}

@end