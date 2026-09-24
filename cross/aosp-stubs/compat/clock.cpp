// adb-rt: POSIX clock_gettime for MSVC. Original work for this project.
//
// Lives in a .cpp, not inline in <time.h>, because the implementation needs <windows.h> and
// windows.h drags in wingdi.h, whose `#define ERROR 0` collides with libbase's
// LogSeverity::ERROR enumerator in android-base/logging.h:90. Containing windows.h to one
// translation unit is the whole point.
#include <time.h>

#include <windows.h>

extern "C" int clock_gettime(clockid_t clk, struct timespec* ts) {
    if (ts == nullptr) return -1;
    if (clk == CLOCK_MONOTONIC) {
        LARGE_INTEGER f, c;
        if (!QueryPerformanceFrequency(&f) || !QueryPerformanceCounter(&c) || f.QuadPart == 0) {
            return -1;
        }
        ts->tv_sec = static_cast<time_t>(c.QuadPart / f.QuadPart);
        ts->tv_nsec = static_cast<long>(((c.QuadPart % f.QuadPart) * 1000000000LL) / f.QuadPart);
        return 0;
    }
    // CLOCK_REALTIME: FILETIME counts 100ns ticks from 1601-01-01; shift to the Unix epoch.
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    unsigned long long t = (static_cast<unsigned long long>(ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
    t -= 116444736000000000ULL;
    ts->tv_sec = static_cast<time_t>(t / 10000000ULL);
    ts->tv_nsec = static_cast<long>((t % 10000000ULL) * 100);
    return 0;
}
