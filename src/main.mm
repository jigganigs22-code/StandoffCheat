#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <pthread.h>
#import <unistd.h>
#import <time.h>
#import <sys/mman.h>
#import <string.h>
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
        {"il2cpp_class_get_methods", (void**)&il2cpp_class_get_methods},
        {"il2cpp_class_get_method_count", (void**)&il2cpp_class_get_method_count},
    };

    int resolved = 0;
    for (auto& b : binds) {
        void* p = bind(handle, b.name);
        if (p) { *b.out = p; resolved++; }
    }

    if (resolved < 30) {
        CHEAT_LOG("t: IL2CPP binding failed %d/%d", resolved, 38);
        return false;
    }
    CHEAT_LOG("t: IL2CPP API bound, %d symbols", resolved);
    return true;
}

#pragma mark - Anti-cheat neutralizer

static void PatchRet(void* ptr) {
    if (!ptr) return;
    size_t pageSize = (size_t)sysconf(_SC_PAGESIZE);
    uintptr_t pageStart = ((uintptr_t)ptr / pageSize) * pageSize;
    size_t pageSizeTotal = pageSize * ((((uintptr_t)ptr - pageStart) + 8 + pageSize - 1) / pageSize);
    if (mprotect((void*)pageStart, pageSizeTotal, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
        // MOV X0, #0 ; RET  →  always return false/null (clean)
        *(volatile uint32_t*)ptr = 0xD2800000;
        *(volatile uint32_t*)((char*)ptr + 4) = 0xD65F03C0;
        mprotect((void*)pageStart, pageSizeTotal, PROT_READ | PROT_EXEC);
    }
}

static void NukeACClass(const Il2CppClass* cls) {
    if (!cls) return;
    const char* clsName = il2cpp_class_get_name(cls);
    const char* nsName = il2cpp_class_get_namespace(cls);
    void* iter = NULL;
    const Il2CppMethodInfo* method;
    int nuked = 0;
    if (il2cpp_class_get_methods) {
        Il2CppIterator iter = NULL;
        while ((method = il2cpp_class_get_methods(cls, &iter)) != NULL) {
            void* nativePtr = *(void**)method;
            if (nativePtr) {
                PatchRet(nativePtr);
                nuked++;
            }
        }
    }
    CHEAT_LOG("n: nuked %s.%s (%d methods)", nsName ? nsName : "?", clsName ? clsName : "?", nuked);
}

static void DisableAntiCheat() {
    if (!il2cpp_domain_get) return;
    const Il2CppDomain* domain = il2cpp_domain_get();
    if (!domain) return;
    size_t count = 0;
    const Il2CppAssembly** assemblies = il2cpp_domain_get_assemblies(domain, &count);
    if (!assemblies) return;

    const char* acNamespaces[] = {
        "Axlebolt.Standoff.Anitcheat",
        "Axlebolt.Standoff.Anticheat",
        NULL
    };
    const char* acClasses[] = {
        "AntiCheatManager",
        "AntiCheatUtility",
        NULL
    };

    for (size_t i = 0; i < count; i++) {
        const Il2CppImage* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        for (int n = 0; acNamespaces[n]; n++) {
            for (int c = 0; acClasses[c]; c++) {
                const Il2CppClass* cls = il2cpp_class_from_name(image, acNamespaces[n], acClasses[c]);
                if (cls) NukeACClass(cls);
            }
        }
    }
}

#pragma mark - Update loop (dedicated IL2CPP worker thread, never main)

static long g_workerTick = 0;

static void WorkerTick() {
    if (!g_hooked || !g_config.initialized) return;
    @autoreleasepool {
        GetRecoilControl()->Update();

        ESP* esp = (ESP*)GetESP();
        esp->Update();

        if (g_config.aimbotEnabled && !g_players.empty()) {
            Aimbot* aim = GetAimbot();
            aim->SetPlayerList(&g_players);
            aim->Update();
        }

        if ((g_workerTick++ % 300) == 0) {
            CHEAT_LOG("w: armed tick=%ld players=%zu", g_workerTick, g_players.size());
        }
    }
}

static void FinishInitialize() {
    CHEAT_LOG("w: FinishInitialize on worker thread");
    if (g_hooked) return;

    if (!il2cpp_domain_get || !il2cpp_domain_get()) { CHEAT_LOG("w: domain not ready"); return; }

    il2cpp_thread_attach(il2cpp_domain_get());

    IL2CPPResolver* r = new IL2CPPResolver();
    if (!r->Initialize()) {
        CHEAT_LOG("w: resolver Initialize FAILED");
        delete r;
        return;
    }

    g_resolver = r;
    g_config.initialized = true;
    g_hooked = true;

    // Layer 2: NOP all anti-cheat methods via IL2CPP runtime
    DisableAntiCheat();

    CHEAT_LOG("w: ready + AC nuked");
}

static void* cheatWorker(void* arg) {
    @autoreleasepool {
        CHEAT_LOG("w: worker start");

        int attempts = 0;
        while (attempts < 900) {
            if (!g_fwHandle) g_fwHandle = LoadIL2CppFunctions();
            if (g_fwHandle && BindIL2CppFunctions(g_fwHandle)) break;
            attempts++;
            usleep(100 * 1000);
        }
        if (!g_fwHandle || !il2cpp_domain_get) { CHEAT_LOG("w: gave up binding"); return NULL; }

        int idle = 0;
        while (idle < 400) {
            usleep(200 * 1000);
            idle++;
            if (!il2cpp_domain_get || !il2cpp_domain_get()) continue;
            FinishInitialize();
            if (g_hooked) break;
        }
        if (!g_hooked) { CHEAT_LOG("w: tapout — never hooked"); return NULL; }

        CHEAT_LOG("w: entering main loop");
        while (true) {
            usleep(16 * 1000);
            WorkerTick();
        }
    }
    return NULL;
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

#pragma mark - Entry

static void* cheatBoot(void*);

__attribute__((constructor))
static void bootInit() {
    // Layer 1: write AC disable flags to UserDefaults BEFORE anything else.
    // The game's AntiCheatManager reads these at C# init (several seconds later).
    // If it respects them, all checks are disabled before they even run.
    @autoreleasepool {
        NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
        [defs setObject:@"true" forKey:@"anticheat.disable.banme"];
        [defs setObject:@"true" forKey:@"anticheat.disable.checkpermission"];
        [defs synchronize];

        // Direct file write backup (Unity reads PlayerPrefs from this plist)
        @try {
            NSString* prefsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.axlebolt.standoff2.plist"];
            NSMutableDictionary* prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefsPath];
            if (!prefs) prefs = [NSMutableDictionary dictionary];
            prefs[@"anticheat.disable.banme"] = @"true";
            prefs[@"anticheat.disable.checkpermission"] = @"true";
            [prefs writeToFile:prefsPath atomically:YES];
        } @catch (NSException* e) { }
    }

    pthread_t boot;
    pthread_create(&boot, NULL, cheatBoot, NULL);
}

static double NowSecs() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static void* cheatBoot(void* arg) {
    @autoreleasepool {
        double bootStart = NowSecs();
        while (true) {
            usleep(500 * 1000);
            if (NowSecs() - bootStart >= 6.0) break;
        }

        if (!IsRunningInStandoff()) return NULL;

        CHEAT_LOG_OPEN();
        CHEAT_INSTALL_CRASH_HANDLERS();
        CHEAT_LOG("init: start (deferred)");

        pthread_t thread;
        pthread_create(&thread, NULL, cheatWorker, NULL);
        ScheduleUI();
    }
    return NULL;
}

@interface R9Shell : NSObject
@end

@implementation R9Shell
@end