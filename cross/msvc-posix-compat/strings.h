// msvc-posix-compat: <strings.h>. UCRT has none; mingw-w64 does.
// The strcasecmp/strncasecmp wrappers live in our <string.h> shim (mingw declares them from
// string.h under _GNU_SOURCE, which is how libbase's strings.cpp reaches them). Defining them
// in BOTH headers causes "redefinition of 'strcasecmp'", so this header just delegates.
#ifndef ADBRT_COMPAT_STRINGS_H
#define ADBRT_COMPAT_STRINGS_H
#include <string.h>
#endif
