// aosp-stubs: <android/log.h> -- the liblog API surface libbase's logging.cpp needs.
//
// WHY A STUB (READING U2). Host adb does NOT log through AOSP's logging backend: libbase's own
// StderrLogger is the host default, and every __android_log_* call in logging.cpp sits inside
// `if (__builtin_available(android 30, *))`, which is false on Windows. What liblog is needed
// for here is DECLARATIONS -- the calls must compile even though they are unreachable.
//
// Types and values mirror AOSP's real <android/log.h> so the ABI of anything that does reach
// them is unchanged. The implementations live in liblog-stub.cpp and write to stderr; see the
// note there about why they must not silently swallow output.
#ifndef ADBRT_STUB_ANDROID_LOG_H
#define ADBRT_STUB_ANDROID_LOG_H

#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/cdefs.h>

__BEGIN_DECLS

typedef enum android_LogPriority {
    ANDROID_LOG_UNKNOWN = 0,
    ANDROID_LOG_DEFAULT,
    ANDROID_LOG_VERBOSE,
    ANDROID_LOG_DEBUG,
    ANDROID_LOG_INFO,
    ANDROID_LOG_WARN,
    ANDROID_LOG_ERROR,
    ANDROID_LOG_FATAL,
    ANDROID_LOG_SILENT,
} android_LogPriority;

typedef enum log_id {
    LOG_ID_MIN = 0,
    LOG_ID_MAIN = 0,
    LOG_ID_RADIO = 1,
    LOG_ID_EVENTS = 2,
    LOG_ID_SYSTEM = 3,
    LOG_ID_CRASH = 4,
    LOG_ID_STATS = 5,
    LOG_ID_SECURITY = 6,
    LOG_ID_KERNEL = 7,
    LOG_ID_MAX,
    LOG_ID_DEFAULT = 0x7FFFFFFF,
} log_id_t;

struct __android_log_message {
    size_t struct_size;
    int32_t buffer_id;
    int32_t priority;
    const char* tag;
    const char* file;
    uint32_t line;
    const char* message;
};

typedef void (*__android_logger_function)(const struct __android_log_message* log_message);
typedef void (*__android_aborter_function)(const char* abort_message);

int __android_log_buf_print(int32_t bufID, int prio, const char* tag, const char* fmt, ...);
void __android_log_write_log_message(struct __android_log_message* log_message);
void __android_log_logd_logger(const struct __android_log_message* log_message);
void __android_log_stderr_logger(const struct __android_log_message* log_message);
void __android_log_set_logger(__android_logger_function logger);
void __android_log_set_aborter(__android_aborter_function aborter);
void __android_log_call_aborter(const char* abort_message);
void __android_log_set_default_tag(const char* tag);
int32_t __android_log_set_minimum_priority(int32_t priority);
int32_t __android_log_get_minimum_priority(void);
int __android_log_is_loggable(int32_t prio, const char* tag, int32_t default_prio);
int __android_log_is_loggable_len(int32_t prio, const char* tag, size_t len, int32_t default_prio);
void android_set_abort_message(const char* msg);

__END_DECLS

#endif  // ADBRT_STUB_ANDROID_LOG_H
