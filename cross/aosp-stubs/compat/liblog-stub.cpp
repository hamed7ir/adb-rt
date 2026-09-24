// aosp-stubs: minimal liblog for the HOST. Original work for this project.
//
// READING U2. libbase's logging.cpp references exactly 10 liblog entry points (measured with
// llvm-nm on logging.cpp.obj, not guessed). On Windows every call site sits inside
// `if (__builtin_available(android 30, *))`, which is false, so host adb's logging really goes
// through libbase's own StderrLogger and none of this is reached.
//
// ⚠ THAT IS EXACTLY WHY THESE MUST NOT BE EMPTY. A stub that satisfies the linker and silently
// swallows output is a BEHAVIOURAL CHANGE disguised as a link fix: if any path ever does reach
// liblog, the log line must still appear. So every function here does the real thing in the
// simplest honest way -- it writes to stderr, and the setter/getter pairs keep real state.
//
// What is NOT implemented, deliberately: the logd socket protocol, log buffers, and
// __android_log_is_loggable's property-based per-tag overrides. A host tool has no logd and no
// Android properties. Severity filtering IS honoured, via the minimum priority.
#include <android/log.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

namespace {

__android_logger_function g_logger = nullptr;
__android_aborter_function g_aborter = nullptr;
const char* g_default_tag = nullptr;
int32_t g_min_priority = ANDROID_LOG_INFO;

char PriorityChar(int32_t p) {
    switch (p) {
        case ANDROID_LOG_VERBOSE: return 'V';
        case ANDROID_LOG_DEBUG:   return 'D';
        case ANDROID_LOG_INFO:    return 'I';
        case ANDROID_LOG_WARN:    return 'W';
        case ANDROID_LOG_ERROR:   return 'E';
        case ANDROID_LOG_FATAL:   return 'F';
        default:                  return '?';
    }
}

// The one place a log line is actually rendered. Mirrors liblog's host format closely enough
// to be recognisable: "<P> <tag>: <message>", with file:line when the caller supplied it.
void WriteToStderr(int32_t priority, const char* tag, const char* file, unsigned int line,
                   const char* message) {
    const char* t = tag ? tag : (g_default_tag ? g_default_tag : "adb");
    if (file != nullptr) {
        fprintf(stderr, "%c %s %s:%u: %s\n", PriorityChar(priority), t, file, line,
                message ? message : "");
    } else {
        fprintf(stderr, "%c %s: %s\n", PriorityChar(priority), t, message ? message : "");
    }
    fflush(stderr);
}

}  // namespace

extern "C" {

void __android_log_write_log_message(struct __android_log_message* m) {
    if (m == nullptr) return;
    if (m->priority < g_min_priority) return;
    if (g_logger != nullptr) {          // honour a logger installed via __android_log_set_logger
        g_logger(m);
        return;
    }
    WriteToStderr(m->priority, m->tag, m->file, m->line, m->message);
}

void __android_log_logd_logger(const struct __android_log_message* m) {
    // No logd on a host. Falling back to stderr keeps the line visible instead of dropping it.
    if (m == nullptr) return;
    WriteToStderr(m->priority, m->tag, m->file, m->line, m->message);
}

void __android_log_stderr_logger(const struct __android_log_message* m) {
    if (m == nullptr) return;
    WriteToStderr(m->priority, m->tag, m->file, m->line, m->message);
}

int __android_log_buf_print(int32_t /*bufID*/, int prio, const char* tag, const char* fmt, ...) {
    if (prio < g_min_priority) return 0;
    va_list ap;
    va_start(ap, fmt);
    char buf[2048];
    const int n = vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    WriteToStderr(prio, tag, nullptr, 0, buf);
    return n;
}

void __android_log_set_logger(__android_logger_function logger) { g_logger = logger; }

void __android_log_set_aborter(__android_aborter_function aborter) { g_aborter = aborter; }

void __android_log_call_aborter(const char* abort_message) {
    if (g_aborter != nullptr) {
        g_aborter(abort_message);
        return;                          // an installed aborter may not return; if it does, fall through
    }
    if (abort_message != nullptr) {
        fprintf(stderr, "%s\n", abort_message);
        fflush(stderr);
    }
    abort();
}

void __android_log_set_default_tag(const char* tag) { g_default_tag = tag; }

int32_t __android_log_set_minimum_priority(int32_t priority) {
    const int32_t old = g_min_priority;
    g_min_priority = priority;
    return old;
}

int32_t __android_log_get_minimum_priority(void) { return g_min_priority; }

int __android_log_is_loggable(int32_t prio, const char* /*tag*/, int32_t default_prio) {
    const int32_t threshold = (g_min_priority != 0) ? g_min_priority : default_prio;
    return prio >= threshold ? 1 : 0;
}

int __android_log_is_loggable_len(int32_t prio, const char* tag, size_t /*len*/,
                                  int32_t default_prio) {
    return __android_log_is_loggable(prio, tag, default_prio);
}

void android_set_abort_message(const char* msg) {
    // No crash-dump slot on a host. Printing it is strictly better than discarding it.
    if (msg != nullptr) {
        fprintf(stderr, "abort message: %s\n", msg);
        fflush(stderr);
    }
}

}  // extern "C"
