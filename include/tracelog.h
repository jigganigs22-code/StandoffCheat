#pragma once
#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif
void CHEAT_LOG(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
void CHEAT_LOG_OPEN(void);
void CHEAT_INSTALL_CRASH_HANDLERS(void);
#ifdef __cplusplus
}
#endif