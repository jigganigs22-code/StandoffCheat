#import "tracelog.h"
#import <Foundation/Foundation.h>
#import <signal.h>
#import <execinfo.h>
#import <sys/time.h>
#import <string.h>
#import <stdio.h>

static FILE* g_traceFile = NULL;

static void OpenLog(void) {
    if (g_traceFile) return;
    NSString* dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (!dir) dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString* path = [dir stringByAppendingPathComponent:@"apptrace.log"];
    NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (attrs && [attrs[NSFileSize] longLongValue] > 1024 * 1024) {
        NSString* old = [dir stringByAppendingPathComponent:@"apptrace.log.old"];
        [[NSFileManager defaultManager] removeItemAtPath:old error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:path toPath:old error:nil];
    }
    g_traceFile = fopen([path UTF8String], "a");
    if (g_traceFile) setvbuf(g_traceFile, NULL, _IONBF, 0);
}

void CHEAT_LOG_OPEN(void) { OpenLog(); }

void CHEAT_LOG(const char* fmt, ...) {
    if (!g_traceFile) OpenLog();
    if (!g_traceFile) return;
    va_list ap;
    va_start(ap, fmt);
    struct timeval tv;
    gettimeofday(&tv, NULL);
    fprintf(g_traceFile, "[%ld.%03d] ", (long)tv.tv_sec, tv.tv_usec / 1000);
    vfprintf(g_traceFile, fmt, ap);
    fprintf(g_traceFile, "\n");
    fflush(g_traceFile);
    va_end(ap);
}

static void CrashHandler(int sig, siginfo_t* info, void* uctx) {
    if (!g_traceFile) OpenLog();
    if (g_traceFile) {
        fprintf(g_traceFile, "\n!!! CRASH signal=%d addr=%p !!!\n", sig, info->si_addr);
        void* stack[64];
        int n = backtrace(stack, 64);
        char** syms = backtrace_symbols(stack, n);
        if (syms) {
            for (int i = 0; i < n; i++) fprintf(g_traceFile, "#%02d %s\n", i, syms[i]);
            free(syms);
        }
        fprintf(g_traceFile, "!!! end crash !!!\n");
        fflush(g_traceFile);
    }
    signal(sig, SIG_DFL);
    raise(sig);
}

void CHEAT_INSTALL_CRASH_HANDLERS(void) {
    static struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = CrashHandler;
    sa.sa_flags = SA_SIGINFO | SA_RESETHAND;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGABRT, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGTRAP, &sa, NULL);
}