// msvc-posix-compat: <libgen.h> (basename/dirname). UCRT has none; mingw-w64 does.
// libbase's file.cpp:22 and logging.cpp:25 include it UNGUARDED.
#ifndef ADBRT_COMPAT_LIBGEN_H
#define ADBRT_COMPAT_LIBGEN_H
#include <sys/cdefs.h>
__BEGIN_DECLS
char* basename(char* path);
char* dirname(char* path);
__END_DECLS
#endif
