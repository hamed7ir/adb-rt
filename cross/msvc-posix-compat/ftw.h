// msvc-posix-compat: <ftw.h> (file tree walk). UCRT has none.
// libbase's file.cpp:21 includes it UNGUARDED. DECLARATIONS ONLY -- whether anything actually
// CALLS nftw on the Windows path is a link-time question, and the linker is the right place to
// find out. Not silently implemented.
#ifndef ADBRT_COMPAT_FTW_H
#define ADBRT_COMPAT_FTW_H
#include <sys/cdefs.h>
#include <sys/stat.h>
__BEGIN_DECLS
#define FTW_F   0
#define FTW_D   1
#define FTW_DNR 2
#define FTW_NS  3
#define FTW_SL  4
#define FTW_DP  5
#define FTW_SLN 6
#define FTW_PHYS  1
#define FTW_MOUNT 2
#define FTW_CHDIR 4
#define FTW_DEPTH 8
struct FTW { int base; int level; };
int ftw(const char* dirpath, int (*fn)(const char*, const struct stat*, int), int nopenfd);
int nftw(const char* dirpath, int (*fn)(const char*, const struct stat*, int, struct FTW*),
         int nopenfd, int flags);
__END_DECLS
#endif
