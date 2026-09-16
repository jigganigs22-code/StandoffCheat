#pragma once
#include <stddef.h>
#include <stdint.h>

typedef struct Il2CppDomain Il2CppDomain;
typedef struct Il2CppAssembly Il2CppAssembly;
typedef struct Il2CppImage Il2CppImage;
typedef struct Il2CppClass Il2CppClass;
typedef struct Il2CppObject Il2CppObject;
typedef struct Il2CppFieldInfo Il2CppFieldInfo;
typedef struct Il2CppMethodInfo Il2CppMethodInfo;
typedef struct Il2CppType Il2CppType;
typedef struct Il2CppThread Il2CppThread;
typedef struct Il2CppException Il2CppException;
typedef struct Il2CppArray Il2CppArray;

extern "C" {
    extern const Il2CppDomain* (*il2cpp_domain_get)();
    extern const Il2CppAssembly** (*il2cpp_domain_get_assemblies)(const Il2CppDomain* domain, size_t* size);
    extern const Il2CppImage* (*il2cpp_assembly_get_image)(const Il2CppAssembly* assembly);
    extern const char* (*il2cpp_image_get_name)(const Il2CppImage* image);

    extern const Il2CppClass* (*il2cpp_class_from_name)(const Il2CppImage* image, const char* ns, const char* name);
    extern const Il2CppFieldInfo* (*il2cpp_class_get_field_from_name)(const Il2CppClass* klass, const char* name);
    extern const Il2CppMethodInfo* (*il2cpp_class_get_method_from_name)(const Il2CppClass* klass, const char* name, int paramCount);
    extern const char* (*il2cpp_class_get_name)(const Il2CppClass* klass);
    extern const char* (*il2cpp_class_get_namespace)(const Il2CppClass* klass);

    extern size_t (*il2cpp_field_get_offset)(const Il2CppFieldInfo* field);
    extern const char* (*il2cpp_field_get_name)(const Il2CppFieldInfo* field);
    extern const Il2CppType* (*il2cpp_field_get_type)(const Il2CppFieldInfo* field);
    extern void (*il2cpp_field_get_value)(void* obj, const Il2CppFieldInfo* field, void* value);
    extern void (*il2cpp_field_set_value)(void* obj, const Il2CppFieldInfo* field, const void* value);
    extern void (*il2cpp_field_static_get_value)(const Il2CppFieldInfo* field, void* value);
    extern void (*il2cpp_field_static_set_value)(const Il2CppFieldInfo* field, const void* value);

    extern Il2CppObject* (*il2cpp_runtime_invoke)(const Il2CppMethodInfo* method, void* obj, void** params, Il2CppException** exc);
    extern Il2CppObject* (*il2cpp_runtime_invoke_varargs)(const Il2CppMethodInfo* method, void* obj, void** params, Il2CppException** exc);
    extern const char* (*il2cpp_method_get_name)(const Il2CppMethodInfo* method);

    extern Il2CppObject* (*il2cpp_object_new)(const Il2CppClass* klass);
    extern Il2CppObject* (*il2cpp_object_unbox)(Il2CppObject* obj);
    extern Il2CppClass* (*il2cpp_object_get_class)(Il2CppObject* obj);

    extern Il2CppThread* (*il2cpp_thread_attach)(const Il2CppDomain* domain);
    extern Il2CppThread* (*il2cpp_thread_current)();
    extern const Il2CppDomain* (*il2cpp_thread_get_domain)(Il2CppThread* thread);

    extern Il2CppClass* (*il2cpp_class_from_il2cpp_type)(const Il2CppType* type);
    extern const Il2CppType* (*il2cpp_class_get_type)(const Il2CppClass* klass);
    extern int (*il2cpp_type_get_type)(const Il2CppType* type);
    extern Il2CppObject* (*il2cpp_type_get_object)(const Il2CppType* type);

    extern Il2CppObject* (*il2cpp_string_new)(const char* str);
    extern size_t (*il2cpp_string_length)(Il2CppObject* str);
    extern const char* (*il2cpp_string_chars)(Il2CppObject* str);

    extern Il2CppArray* (*il2cpp_array_new)(const Il2CppClass* klass, uintptr_t len);
    extern Il2CppArray* (*il2cpp_array_new_specific)(const Il2CppClass* klass, uintptr_t len);
    extern Il2CppClass* (*il2cpp_array_class_get)(const Il2CppClass* klass, uint32_t rank);
    extern void* (*il2cpp_array_get)(const Il2CppArray* arr, uintptr_t index);
    extern uintptr_t (*il2cpp_array_length)(const Il2CppArray* arr);

    typedef void* Il2CppIterator;
    extern const Il2CppMethodInfo* (*il2cpp_class_get_methods)(const Il2CppClass* klass, Il2CppIterator** iter);
    extern int (*il2cpp_class_get_method_count)(const Il2CppClass* klass);
}