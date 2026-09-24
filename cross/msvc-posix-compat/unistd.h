// msvc-posix-compat: minimal <unistd.h>. UCRT has no such header; mingw-w64 does.
// Reached via android-base/macros.h ("for TEMP_FAILURE_RETRY"), unique_fd.h and utf8.h.
#ifndef ADBRT_COMPAT_UNISTD_H
#define ADBRT_COMPAT_UNISTD_H
#include <io.h>          // _close/_read/_write/_lseek/_access/_isatty/_dup
#include <direct.h>      // _getcwd/_chdir/_rmdir
#include <process.h>     // _getpid/_execv
#include <stddef.h>
#include <sys/cdefs.h>
// POSIX declares getopt/optind/optarg in <unistd.h>, and mingw-w64's unistd.h pulls in
// getopt.h accordingly. client/commandline.cpp relies on that: it uses optind and
// getopt_long WITHOUT including <getopt.h> itself.
#include <getopt.h>
// mingw's unistd.h also reaches the POSIX case-insensitive compares
#include <strings.h>

#ifndef _SSIZE_T_DEFINED
#  define _SSIZE_T_DEFINED
#  include <BaseTsd.h>
typedef SSIZE_T ssize_t;
#endif

// POSIX spellings over the UCRT underscore names. adb's sysdeps.h POISONS the bare names
// AFTER these headers are included, which is exactly why the ordering above matters.
#ifndef ADBRT_COMPAT_NO_POSIX_ALIASES
#  define STDIN_FILENO  0
#  define STDOUT_FILENO 1
#  define STDERR_FILENO 2
#endif

// ftruncate: libbase test_utils.cpp:55. UCRT spells it _chsize_s.
#ifdef __cplusplus
extern "C++" {
inline int ftruncate(int fd, long long length) { return _chsize_s(fd, length); }
}
#endif

// access() mode bits. mingw-w64 defines them; the UCRT only has the bare numbers for _access.
// adb.cpp:784 uses F_OK. X_OK has no meaning on Windows -- mingw maps it to F_OK too, since
// NTFS execute permission is not what _access reports.
#ifndef F_OK
#  define F_OK 0
#  define X_OK 0
#  define W_OK 2
#  define R_OK 4
#endif

#ifndef TEMP_FAILURE_RETRY
// Win32 has no EINTR restart semantics; evaluate once. This is the mingw behaviour adb
// already relies on for _WIN32.
#  define TEMP_FAILURE_RETRY(exp) (exp)
#endif
#endif
