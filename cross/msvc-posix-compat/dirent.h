// msvc-posix-compat: minimal <dirent.h>. UCRT has no such header; mingw-w64 does.
// DECLARATIONS ONLY at catalogue stage -- -fsyntax-only needs no bodies. The
// implementation is owed at link time (READING D6) and is tracked as such.
#ifndef ADBRT_COMPAT_DIRENT_H
#define ADBRT_COMPAT_DIRENT_H
#include <stddef.h>
#include <sys/cdefs.h>
__BEGIN_DECLS
#ifndef NAME_MAX
#  define NAME_MAX 255
#endif
struct dirent {
    unsigned long d_ino;
    unsigned short d_reclen;
    unsigned char  d_type;
    char           d_name[NAME_MAX + 1];
};
#define DT_UNKNOWN 0
#define DT_DIR     4
#define DT_REG     8
typedef struct DIR DIR;
DIR*            opendir(const char* name);
struct dirent*  readdir(DIR* dirp);
int             closedir(DIR* dirp);
void            rewinddir(DIR* dirp);

/* mingw-w64 also ships the WIDE variants, and adb's sysdeps_win32.cpp uses them
   (_wopendir/_wreaddir/_wclosedir/_WDIR/_wdirent) because its Windows path is all UTF-16. */
struct _wdirent {
    unsigned long  d_ino;
    unsigned short d_reclen;
    unsigned short d_namlen;
    wchar_t        d_name[260];
};
typedef struct _WDIR _WDIR;
_WDIR*           _wopendir(const wchar_t* name);
struct _wdirent* _wreaddir(_WDIR* dirp);
int              _wclosedir(_WDIR* dirp);
void             _wrewinddir(_WDIR* dirp);
__END_DECLS
#endif
