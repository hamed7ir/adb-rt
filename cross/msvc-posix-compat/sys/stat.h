// msvc-posix-compat: UCRT's <sys/stat.h> EXTENDED with the POSIX bits mingw-w64 supplies.
//
// TWO gaps, both hit by adb:
//
// 1. S_ISDIR / S_ISREG / ... -- UCRT defines _S_IFDIR and S_IFDIR but NO S_IS* test macros
//    (measured: 0 occurrences of "S_ISDIR" in the UCRT header). adb_utils.cpp uses S_ISDIR.
//
// 2. wstat() -- adb's sysdeps/win32/stat.cpp says, verbatim:
//       "<sys/stat.h> has a function prototype for wstat() that should be available."
//    True on mingw-w64, false on UCRT, which only has the underscore-prefixed _wstat*.
//
//    Do NOT "fix" this with -D_FILE_OFFSET_BITS=64. That makes adb's own code define
//    wstat -> _wstat64, which takes `struct _stat64*`. But adb declares
//    `struct adb_stat : public stat {}` (sysdeps/stat.h:38), and on UCRT `struct stat` is
//    _stat64i32, NOT _stat64 -- so the call fails with "no matching function for call to
//    '_wstat64'". On mingw, _FILE_OFFSET_BITS=64 makes `struct stat` genuinely _stat64,
//    which is why upstream never saw this.
//
//    The right size-matched alias on UCRT is _wstat64i32. Passing `struct adb_stat*` to it
//    is a plain derived-to-base pointer conversion.
#ifndef ADBRT_COMPAT_SYS_STAT_H
#define ADBRT_COMPAT_SYS_STAT_H
#include_next <sys/stat.h>

#ifndef S_ISDIR
#  define S_ISDIR(m)  (((m) & _S_IFMT) == _S_IFDIR)
#  define S_ISREG(m)  (((m) & _S_IFMT) == _S_IFREG)
#  define S_ISCHR(m)  (((m) & _S_IFMT) == _S_IFCHR)
#  define S_ISFIFO(m) (((m) & _S_IFMT) == _S_IFIFO)
#  define S_ISLNK(m)  (0)   /* UCRT has no S_IFLNK; mingw's is also always false */
#endif

// POSIX permission bits. UCRT has _S_IREAD/_S_IWRITE/_S_IEXEC and ZERO occurrences of
// S_IRUSR. mingw-w64 defines the POSIX spellings, which client/adb_wifi.cpp uses.
#ifndef S_IRUSR
#  define S_IRUSR _S_IREAD
#  define S_IWUSR _S_IWRITE
#  define S_IXUSR _S_IEXEC
#  define S_IRWXU (_S_IREAD | _S_IWRITE | _S_IEXEC)
#  define S_IRGRP 0
#  define S_IWGRP 0
#  define S_IXGRP 0
#  define S_IROTH 0
#  define S_IWOTH 0
#  define S_IXOTH 0
#endif

// wstat(): a #define alias does NOT work. UCRT declares `struct _stat64i32` (line 54) and a
// SEPARATE `struct stat` (line 87) -- distinct types with asserted-equal size. UCRT's own
// inline stat()/fstat() wrappers cast between them (line 236). Mirror that exactly, so
// `struct adb_stat : public stat {}` converts to `struct stat*` by plain derived-to-base.
#if defined(__cplusplus) && !defined(wstat)
#  ifdef _USE_32BIT_TIME_T
static inline int wstat(wchar_t const* const _FileName, struct stat* const _Stat) {
    return _wstat32(_FileName, (struct _stat32*)_Stat);
}
#  else
static inline int wstat(wchar_t const* const _FileName, struct stat* const _Stat) {
    return _wstat64i32(_FileName, (struct _stat64i32*)_Stat);
}
#  endif
#endif
#endif
