// msvc-posix-compat: UCRT's <stdio.h> EXTENDED with the GNU asprintf family.
// mingw-w64 declares asprintf/vasprintf under _GNU_SOURCE (which adb_defaults defines for
// Windows); UCRT has neither. client/commandline.cpp:1688,1690 calls asprintf.
//
// ⚠ DECLARATION ONLY -> LINK DEBT, tracked for READING D6, not solved here.
#ifndef ADBRT_COMPAT_STDIO_H
#define ADBRT_COMPAT_STDIO_H
#include_next <stdio.h>
#include <stdarg.h>
#include <sys/cdefs.h>
__BEGIN_DECLS
int asprintf(char** strp, const char* fmt, ...);
int vasprintf(char** strp, const char* fmt, va_list ap);
__END_DECLS
#endif
