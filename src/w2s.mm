#import "w2s.h"
#import "il2cpp_resolver.h"

extern IL2CPPResolver* GetResolver();

Vector3 WorldToScreenPoint(void* camera, Vector3 world) {
    auto* r = GetResolver();
    if (!r || !camera || !r->classes.Camera) return {};
    const Il2CppMethodInfo* m = il2cpp_class_get_method_from_name(r->classes.Camera, "WorldToScreenPoint", 1);
    if (!m) return {};
    Il2CppException* exc = nullptr;
    void* params[] = { &world };
    Il2CppObject* result = il2cpp_runtime_invoke(m, camera, params, &exc);
    if (!result || exc) return {};
    return *(Vector3*)il2cpp_object_unbox(result);
}

Vector3 GetTransformPositionShared(void* transform) {
    auto* r = GetResolver();
    if (!r || !transform || !r->classes.Transform) return {};
    const Il2CppMethodInfo* m = il2cpp_class_get_method_from_name(r->classes.Transform, "get_position", 0);
    if (!m) return {};
    Il2CppObject* res = il2cpp_runtime_invoke(m, transform, nullptr, nullptr);
    if (!res) return {};
    return *(Vector3*)il2cpp_object_unbox(res);
}

void* GetComponentOn(void* component, void* componentClass) {
    auto* r = GetResolver();
    if (!r || !component || !r->classes.Component) return nullptr;
    const Il2CppMethodInfo* m = il2cpp_class_get_method_from_name(r->classes.Component, "GetComponent", 1);
    if (!m) return nullptr;
    Il2CppException* exc = nullptr;
    void* params[] = { componentClass };
    return (void*)il2cpp_runtime_invoke(m, component, params, &exc);
}