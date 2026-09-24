// msvc-posix-compat: UCRT <limits.h> EXTENDED with SSIZE_MAX.
// libbase file.cpp:225 uses it; UCRT has no SSIZE_MAX, mingw-w64 does.
#ifndef ADBRT_COMPAT_LIMITS_H
#define ADBRT_COMPAT_LIMITS_H
#include_next <limits.h>
#ifndef SSIZE_MAX
#  ifdef _WIN64
#    define SSIZE_MAX _I64_MAX
#  else
#    define SSIZE_MAX INT_MAX
#  endif
#endif
#endif
