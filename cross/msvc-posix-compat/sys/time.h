// msvc-posix-compat: minimal <sys/time.h>. UCRT has no such header.
// struct timeval comes from winsock2.h on Windows, exactly as mingw arranges it.
#ifndef ADBRT_COMPAT_SYS_TIME_H
#define ADBRT_COMPAT_SYS_TIME_H
#include <winsock2.h>
#include <time.h>
#include <sys/cdefs.h>
__BEGIN_DECLS
struct timezone { int tz_minuteswest; int tz_dsttime; };
int gettimeofday(struct timeval* tv, struct timezone* tz);
__END_DECLS
#endif
