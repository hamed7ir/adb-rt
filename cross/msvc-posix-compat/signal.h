// msvc-posix-compat: UCRT's <signal.h> EXTENDED with the POSIX signal numbers mingw-w64
// declares. MSVC's signal.h has only SIGINT/SIGILL/SIGFPE/SIGSEGV/SIGTERM/SIGBREAK/SIGABRT.
//
// client/commandline.cpp uses SIGPIPE UNGUARDED: `signal(SIGPIPE, SIG_IGN)` at :1563 and
// `SIGPIPE + 128` at :306 and :311.
//
// ⚠ RUNTIME CAVEAT: this makes it COMPILE, matching mingw. Neither CRT ever RAISES SIGPIPE on
// Windows, and the MSVC CRT's signal() rejects an unsupported number with SIG_ERR. adb
// discards signal()'s return value, so behaviour matches the mingw build -- but this is a
// compile-time fix with a runtime difference, and it is NOT verified on device.
#ifndef ADBRT_COMPAT_SIGNAL_H
#define ADBRT_COMPAT_SIGNAL_H
#include_next <signal.h>
#ifndef SIGPIPE
#  define SIGPIPE 13   /* mingw-w64's value */
#endif
#ifndef SIGQUIT
#  define SIGQUIT 3
#endif
#ifndef SIGKILL
#  define SIGKILL 9
#endif
#ifndef SIGHUP
#  define SIGHUP 1
#endif
#endif
