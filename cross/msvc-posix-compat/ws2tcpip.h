// msvc-posix-compat: SDK <ws2tcpip.h> EXTENDED to pull in <mstcpip.h>.
//
// sysdeps_win32.cpp uses `struct tcp_keepalive` and SIO_KEEPALIVE_VALS, which the Windows SDK
// declares in <mstcpip.h> -- a header its own ws2tcpip.h does NOT include. mingw-w64's
// ws2tcpip.h does, so upstream never had to include it explicitly.
// Same class as the mswsock.h order shim: the SDK headers are less self-sufficient than mingw's.
#ifndef ADBRT_COMPAT_WS2TCPIP_H
#define ADBRT_COMPAT_WS2TCPIP_H
#include_next <ws2tcpip.h>
#include <mstcpip.h>
#endif
