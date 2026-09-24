// adb-rt: asprintf/vasprintf for MSVC. Written for this project; no third-party code vendored.
//
// WHY: these are GNU extensions. mingw-w64 declares and implements them under _GNU_SOURCE
// (which adb_defaults defines for the Windows target); the MSVC UCRT has neither.
// client/commandline.cpp:1688,1690 calls asprintf.
//
// Two vsnprintf passes: one to size, one to format. vsnprintf on the UCRT returns the length
// that WOULD have been written (C99 semantics), which is what makes the sizing pass valid --
// the old _vsnprintf returning -1 on overflow is a different function and is not used here.
#include <stdio.h>

#include <stdarg.h>
#include <stdlib.h>

extern "C" {

int vasprintf(char** strp, const char* fmt, va_list ap) {
    if (strp == nullptr) return -1;
    *strp = nullptr;

    va_list ap2;
    va_copy(ap2, ap);
    const int n = vsnprintf(nullptr, 0, fmt, ap2);
    va_end(ap2);
    if (n < 0) return -1;

    char* buf = static_cast<char*>(malloc(static_cast<size_t>(n) + 1));
    if (buf == nullptr) return -1;

    const int w = vsnprintf(buf, static_cast<size_t>(n) + 1, fmt, ap);
    if (w < 0) {
        free(buf);
        return -1;
    }
    buf[n] = '\0';
    *strp = buf;
    return w;
}

int asprintf(char** strp, const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    const int r = vasprintf(strp, fmt, ap);
    va_end(ap);
    return r;
}

}  // extern "C"
