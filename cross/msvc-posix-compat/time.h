// msvc-posix-compat: UCRT <time.h> EXTENDED with the POSIX _r reentrant variants.
//
// libbase's logging.cpp uses localtime_r. mingw-w64 declares it when
// _POSIX_THREAD_SAFE_FUNCTIONS is defined (which libbase_cflags_defaults does define for
// windows); the UCRT has only localtime_s -- and with the ARGUMENTS REVERSED:
//   POSIX : struct tm* localtime_r(const time_t* t, struct tm* out)
//   UCRT  : errno_t    localtime_s(struct tm* out, const time_t* t)
// Getting that order wrong compiles and then misbehaves at runtime, so the wrapper is written
// once, here.
#ifndef ADBRT_COMPAT_TIME_H
#define ADBRT_COMPAT_TIME_H
#include_next <time.h>
#include <sys/cdefs.h>
// clock_gettime + CLOCK_REALTIME/CLOCK_MONOTONIC. mingw-w64 has them; the UCRT has neither.
// libbase logging.cpp uses CLOCK_REALTIME. IMPLEMENTED (not declared) -- an inline definition
// means no link debt and no extra object.
// clock_gettime + CLOCK_REALTIME/CLOCK_MONOTONIC. mingw-w64 has them; the UCRT has neither.
// libbase logging.cpp uses CLOCK_REALTIME.
//
// ⚠ DECLARED here, IMPLEMENTED in cross/aosp-stubs/compat/clock.cpp -- deliberately.
// An inline version would need <windows.h> in this header, and windows.h drags in wingdi.h,
// which #defines ERROR. That collides with libbase's own LogSeverity::ERROR enumerator:
//   android-base/logging.h(90,3): error: expected identifier
//        90 |   ERROR,
//           |   ^
//   wingdi.h(118,29): note: expanded from macro 'ERROR'
// A compat header must not poison every translation unit that includes <time.h>.
#ifndef CLOCK_REALTIME
#  define CLOCK_REALTIME  0
#  define CLOCK_MONOTONIC 1
typedef int clockid_t;
__BEGIN_DECLS
int clock_gettime(clockid_t clk, struct timespec* ts);
__END_DECLS
#endif

#if defined(__cplusplus) && !defined(localtime_r)
extern "C++" {
inline struct tm* localtime_r(const time_t* t, struct tm* out) {
    return (localtime_s(out, t) == 0) ? out : nullptr;
}
inline struct tm* gmtime_r(const time_t* t, struct tm* out) {
    return (gmtime_s(out, t) == 0) ? out : nullptr;
}
inline char* ctime_r(const time_t* t, char* buf) {
    return (ctime_s(buf, 26, t) == 0) ? buf : nullptr;
}
inline char* asctime_r(const struct tm* tm_in, char* buf) {
    return (asctime_s(buf, 26, tm_in) == 0) ? buf : nullptr;
}
}
#endif
#endif
