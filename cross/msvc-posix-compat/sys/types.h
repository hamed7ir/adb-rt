// msvc-posix-compat: UCRT's <sys/types.h> EXTENDED, not replaced.
//
// #include_next pulls in the real UCRT header first: this directory is on -I, which clang
// searches BEFORE the system include path, so the "next" match is genuinely UCRT's.
// UCRT declares off_t but has NO mode_t at all, and no off64_t; mingw-w64 has both, which
// is why AOSP's Windows build never noticed.
#ifndef ADBRT_COMPAT_SYS_TYPES_H
#define ADBRT_COMPAT_SYS_TYPES_H
#include_next <sys/types.h>
#ifndef _MODE_T_DEFINED
#  define _MODE_T_DEFINED
typedef unsigned short mode_t;      // mingw-w64 spelling (== UCRT's _mode_t)
#endif
#ifndef _PID_T_DEFINED
#  define _PID_T_DEFINED
typedef int pid_t;            // mingw-w64 spelling; libbase process.cpp:29 uses it
#endif
#ifndef _OFF64_T_DEFINED
#  define _OFF64_T_DEFINED
typedef long long off64_t;          // mingw-w64 spelling
#endif
#endif
