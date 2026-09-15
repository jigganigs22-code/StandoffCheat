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

IL2CPPResolver* g_resolver = nullptr;
void* g_localPlayer = nullptr;
void* g_mainCamera = nullptr;
bool g_firingDetected = true;
std::vector<PlayerData> g_players;
std::recursive_mutex g_playersMutex;
CheatConfig g_config;

static bool g_hooked = false;
static dispatch_source_t g_timer = nil;

static void HookRenderLoop();
static void TryInitialize();
static void UpdateLoop();

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
    if (!handle) handle = dlopen(NULL, RTLD_NOW);
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
        NSLog(@"[StandoffCheat] IL2CPP binding failed: %d/%d resolved", resolved, 34);
        return false;
    }
    NSLog(@"[StandoffCheat] IL2CPP API bound: %d symbols", resolved);
    return true;
}

static void TryInitialize() {
    if (g_hooked) return;

    void* handle = LoadIL2CppFunctions();
    if (!handle) return;

    if (!BindIL2CppFunctions(handle)) return;

    if (!il2cpp_domain_get) return;

    g_resolver = new IL2CPPResolver();
    if (!g_resolver->Initialize()) {
        delete g_resolver;
        g_resolver = nullptr;
        return;
    }

    g_config.initialized = true;
    g_hooked = true;
    NSLog(@"[StandoffCheat] Initialized — IL2CPP hooked, game ready");
}

#pragma mark - Update loop

static void UpdateLoop() {
    if (!g_hooked) return;
    il2cpp_thread_attach(il2cpp_domain_get());

    GetRecoilControl()->Update();

    ESP* esp = (ESP*)GetESP();
    esp->Update();

    if (g_config.aimbotEnabled && g_players.size() > 0) {
        Aimbot* aim = GetAimbot();
        aim->SetPlayerList(&g_players);
        aim->Update();
    }
}

static void HookRenderLoop() {
    if (g_timer) return;

    double interval = 1.0 / 60.0;
    g_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                     dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    dispatch_source_set_timer(g_timer, dispatch_walltime(NULL, 0),
                              (uint64_t)(interval * NSEC_PER_SEC),
                              (uint64_t)(interval * NSEC_PER_SEC * 0.5));
    dispatch_source_set_event_handler(g_timer, ^{
        UpdateLoop();
    });
    dispatch_resume(g_timer);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        ShowMenu();
        SetupOverlayWindow();
    });
}

static void* initThread(void* arg) {
    @autoreleasepool {
        int attempts = 0;
        while (!g_hooked && attempts < 300) {
            TryInitialize();
            usleep(200 * 1000);
            attempts++;
        }
        if (g_hooked) {
            NSLog(@"[StandoffCheat] Bootstrap complete after %d attempts", attempts);
            HookRenderLoop();
        } else {
            NSLog(@"[StandoffCheat] Give up — IL2CPP never became available");
        }
    }
    return NULL;
}

#pragma mark - Entry

__attribute__((constructor))
static void StandoffCheatInit() {
    if (!IsRunningInStandoff()) return;

    NSLog(@"[StandoffCheat] Starting — Standoff 2 cheat");

    pthread_t thread;
    pthread_create(&thread, NULL, initThread, NULL);
}

@interface StandoffCheatLoader : NSObject
@end

@implementation StandoffCheatLoader

+ (void)load {
    if (!IsRunningInStandoff()) return;
    NSLog(@"[StandoffCheat] Loader attached");
}

@end