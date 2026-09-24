// msvc-posix-compat: UCRT <string.h> EXTENDED with the POSIX case-insensitive compares.
//
// libbase's strings.cpp uses strncasecmp (lines 100, 113) but includes only <string.h>, never
// <strings.h>. mingw-w64 declares strcasecmp/strncasecmp from string.h under _GNU_SOURCE
// (which adb_defaults defines for Windows), which is why upstream never noticed.
// Inline wrappers over the UCRT equivalents -- no link debt.
#ifndef ADBRT_COMPAT_STRING_H
#define ADBRT_COMPAT_STRING_H
#include_next <string.h>
#ifdef __cplusplus
extern "C++" {
inline int strcasecmp(const char* a, const char* b) { return _stricmp(a, b); }
inline int strncasecmp(const char* a, const char* b, size_t n) { return _strnicmp(a, b, n); }
// mempcpy: GNU extension (memcpy that returns the END of the destination). mingw-w64 has it
// under _GNU_SOURCE; the UCRT does not. client/file_sync_client.cpp uses it.
// adb's own sysdeps.h defines it for __APPLE__ only, which is why _WIN32 was never covered.
inline void* mempcpy(void* dst, const void* src, size_t n) {
    return static_cast<char*>(memcpy(dst, src, n)) + n;
}
}
#endif
#endif
