// msvc-posix-compat: minimal <sys/param.h> (MIN/MAX/PATH_MAX). UCRT has no such header.
#ifndef ADBRT_COMPAT_SYS_PARAM_H
#define ADBRT_COMPAT_SYS_PARAM_H
#include <stdlib.h>
#include <limits.h>
#ifndef PATH_MAX
#  define PATH_MAX _MAX_PATH
#endif
#ifndef MIN
#  define MIN(a, b) (((a) < (b)) ? (a) : (b))
#endif
#ifndef MAX
#  define MAX(a, b) (((a) > (b)) ? (a) : (b))
#endif
#endif
