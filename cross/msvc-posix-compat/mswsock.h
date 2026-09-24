// msvc-posix-compat: ORDER-FIXING shim for <mswsock.h>.
//
// adb's sysdeps.h includes its Windows headers ALPHABETICALLY: mswsock.h at line 66,
// windows.h at 71, winsock2.h at 72. Under mingw-w64 that is fine -- mingw's mswsock.h
// pulls in what it needs. The Windows SDK's mswsock.h does NOT: it assumes winsock2.h and
// windows.h are already included, so it fails with 141 errors of the form
// "unknown type name 'LONG' / 'ULONG' / 'ULONGLONG'" out of shared/mswsockdef.h.
//
// Measured: NOT caused by _POSIX_SOURCE -- a probe including winsock2.h + windows.h +
// mswsock.h compiles with 0 errors both with and without that define.
//
// Fixing the ORDER here keeps deps/adb-35.0.2 byte-identical to upstream.
#ifndef ADBRT_COMPAT_MSWSOCK_H
#define ADBRT_COMPAT_MSWSOCK_H
#include <winsock2.h>
#include <windows.h>
#include_next <mswsock.h>
#endif
