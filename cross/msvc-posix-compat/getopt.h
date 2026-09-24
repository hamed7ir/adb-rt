// msvc-posix-compat: <getopt.h>. UCRT has none; mingw-w64 ships getopt with a real
// implementation. client/commandline.cpp uses optind/optarg and getopt_long.
//
// DECLARATIONS ONLY. This lets the catalogue measure what is behind it; the IMPLEMENTATION
// is genuinely owed at link time (READING D6) and is tracked as an open item, NOT as solved.
#ifndef ADBRT_COMPAT_GETOPT_H
#define ADBRT_COMPAT_GETOPT_H
#include <sys/cdefs.h>
__BEGIN_DECLS
extern char* optarg;
extern int optind, opterr, optopt;
struct option { const char* name; int has_arg; int* flag; int val; };
#define no_argument       0
#define required_argument 1
#define optional_argument 2
int getopt(int argc, char* const argv[], const char* optstring);
int getopt_long(int argc, char* const argv[], const char* optstring,
                const struct option* longopts, int* longindex);
int getopt_long_only(int argc, char* const argv[], const char* optstring,
                     const struct option* longopts, int* longindex);
__END_DECLS
#endif
