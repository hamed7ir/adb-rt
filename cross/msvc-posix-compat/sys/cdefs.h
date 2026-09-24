// msvc-posix-compat: mingw/bionic <sys/cdefs.h>. UCRT has no such header.
#ifndef ADBRT_COMPAT_SYS_CDEFS_H
#define ADBRT_COMPAT_SYS_CDEFS_H
#ifdef __cplusplus
#  define __BEGIN_DECLS extern "C" {
#  define __END_DECLS   }
#else
#  define __BEGIN_DECLS
#  define __END_DECLS
#endif
#ifndef __predict_true
#  define __predict_true(x)  (x)
#  define __predict_false(x) (x)
#endif
#ifndef __INTRODUCED_IN
#  define __INTRODUCED_IN(x)
#endif
#ifndef __printflike
#  define __printflike(a, b)
#endif
#endif
