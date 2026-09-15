#import "recoil.h"
#import "il2cpp_resolver.h"

extern IL2CPPResolver* GetResolver();
static RecoilControl s_recoil;

static void* GetComponentOnObject(void* obj, const Il2CppClass* klass) {
    auto* r = GetResolver();
    if (!r || !obj || !klass) return nullptr;
    const Il2CppMethodInfo* m = il2cpp_class_get_method_from_name(r->classes.Component, "GetComponent", 1);
    if (!m) return nullptr;
    void* params[] = { (void*)klass };
    return (void*)il2cpp_runtime_invoke(m, obj, params, nullptr);
}

void RecoilControl::Update() {
    if (!g_config.initialized || !g_config.recoilEnabled) return;

    auto* r = GetResolver();
    if (!r || !r->classes.RecoilControl || !r->classes.GameObject || !r->classes.Component) return;

    const Il2CppMethodInfo* findObj = il2cpp_class_get_method_from_name(r->classes.GameObject, "Find", 1);
    if (!findObj) return;

    const char* targets[] = {"Weapon", "Weapon(Clone)", "Guns", "Gun", nullptr};
    for (int i = 0; targets[i]; i++) {
        Il2CppObject* nameStr = il2cpp_string_new(targets[i]);
        if (!nameStr) continue;
        Il2CppException* exc = nullptr;
        void* params[] = { nameStr };
        Il2CppObject* found = il2cpp_runtime_invoke(findObj, nullptr, params, &exc);
        if (!found || exc) continue;

        void* recoil = GetComponentOnObject(found, r->classes.RecoilControl);
        if (!recoil) continue;

        const char* fields[] = {"_multiplier", "multiplier", "RecoilMultiplier",
                                "_recoilMultiplier", "recoilMultiplier", "_curve", nullptr};
        for (int f = 0; fields[f]; f++) {
            const Il2CppFieldInfo* field = il2cpp_class_get_field_from_name(r->classes.RecoilControl, fields[f]);
            if (!field) continue;
            float zero = 0.0f;
            il2cpp_field_set_value(recoil, field, &zero);
        }
        break;
    }
}

RecoilControl* GetRecoilControl() {
    return &s_recoil;
}