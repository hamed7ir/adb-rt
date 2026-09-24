// msvc-posix-compat: UCRT/SDK <winsock2.h> EXTENDED with the POSIX shutdown() constants.
//
// mingw-w64's winsock2.h defines SHUT_RD / SHUT_WR / SHUT_RDWR; the Windows SDK defines only
// SD_RECEIVE / SD_SEND / SD_BOTH. adb's sysdeps.h uses SHUT_RDWR as a DEFAULT ARGUMENT
// (lines 111 and 487: `int adb_shutdown(borrowed_fd fd, int direction = SHUT_RDWR)`), so 26
// of 49 sources failed on it.
//
// #include_next reaches the real SDK header: this directory is on -I, searched before the
// system include path. Values are the SD_* ones, which is exactly how mingw defines them.
#ifndef ADBRT_COMPAT_WINSOCK2_H
#define ADBRT_COMPAT_WINSOCK2_H
#include_next <winsock2.h>
#ifndef SHUT_RD
#  define SHUT_RD   SD_RECEIVE   /* 0 */
#  define SHUT_WR   SD_SEND      /* 1 */
#  define SHUT_RDWR SD_BOTH      /* 2 */
#endif
#endif
