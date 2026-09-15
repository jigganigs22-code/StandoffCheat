#pragma once
#import "cheat_data.h"
#import "il2cpp_api.h"

Vector3 WorldToScreenPoint(void* camera, Vector3 world);
Vector3 GetTransformPositionShared(void* transform);
void* GetComponentOn(void* component, void* componentClass);