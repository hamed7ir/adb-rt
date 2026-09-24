// adb-rt: POSIX getopt() for MSVC. Written for this project; no third-party code vendored.
//
// WHY: mingw-w64 ships a real getopt; the MSVC UCRT does not. adb's client/commandline.cpp
// uses getopt(), optind and optarg (lines 709-745, 801-809, 2045-2070) and never includes
// <getopt.h> itself -- POSIX declares these in <unistd.h>, and mingw's unistd.h pulls getopt
// in, which is why upstream never noticed.
//
// SCOPE, measured not assumed: the host adb source set uses ONLY getopt/optind/optarg.
// getopt_long appears exclusively in tools/adb_usbreset.cpp, which is NOT one of the 49
// sources we build. getopt_long/getopt_long_only are therefore declared (in
// cross/msvc-posix-compat/getopt.h) but deliberately NOT implemented here -- if a future
// batch pulls in a source that needs them, the LINKER will say so, which is the honest
// failure mode. A silently wrong getopt_long would be worse than an undefined symbol.
//
// Behaviour implemented, to the POSIX spec adb relies on:
//   * "x"   flag option
//   * "x:"  option with a required argument, taken from the rest of argv[i] or the next argv
//   * ":"   leading colon in optstring -> return ':' (not '?') on a missing argument, silently
//   * "+"   leading plus -> stop at the first non-option operand. Note that plain POSIX
//           getopt ALREADY stops there (it is GNU that permutes), so honouring '+' here means
//           simply not permuting. adb passes "+e:ntTx".
//   * optind is settable by the caller; adb resets it to 1 before each parse.
#include <getopt.h>

#include <stdio.h>
#include <string.h>

extern "C" {

char* optarg = nullptr;
int optind = 1;
int opterr = 1;
int optopt = 0;

// index of the next character within argv[optind], for clustered flags like -ntT
static int s_nextchar = 0;

int getopt(int argc, char* const argv[], const char* optstring) {
    optarg = nullptr;

    bool silent = false;
    const char* spec = optstring;
    // leading '+' (stop at first operand -- we never permute, so this is the default) and
    // leading ':' (silent, report missing argument as ':') may appear in either order.
    for (;;) {
        if (*spec == '+') {
            ++spec;
        } else if (*spec == ':') {
            silent = true;
            ++spec;
        } else {
            break;
        }
    }

    if (optind < 1) optind = 1;

    if (s_nextchar == 0) {
        if (optind >= argc) return -1;
        const char* cur = argv[optind];
        if (cur == nullptr || cur[0] != '-' || cur[1] == '\0') return -1;  // operand, or bare "-"
        if (cur[1] == '-' && cur[2] == '\0') {                             // "--" ends options
            ++optind;
            return -1;
        }
        s_nextchar = 1;
    }

    const char* cur = argv[optind];
    const char c = cur[s_nextchar];
    optopt = static_cast<unsigned char>(c);

    const char* match = (c == ':') ? nullptr : strchr(spec, c);
    if (match == nullptr) {
        // advance past the bad character so we cannot loop forever
        if (cur[++s_nextchar] == '\0') {
            ++optind;
            s_nextchar = 0;
        }
        if (opterr && !silent) {
            fprintf(stderr, "%s: invalid option -- '%c'\n", argv[0] ? argv[0] : "adb", c);
        }
        return '?';
    }

    if (match[1] == ':') {  // takes an argument
        if (cur[s_nextchar + 1] != '\0') {
            optarg = const_cast<char*>(cur + s_nextchar + 1);  // -xVALUE
            ++optind;
        } else if (optind + 1 < argc) {
            optarg = argv[optind + 1];  // -x VALUE
            optind += 2;
        } else {
            ++optind;
            s_nextchar = 0;
            if (opterr && !silent) {
                fprintf(stderr, "%s: option requires an argument -- '%c'\n",
                        argv[0] ? argv[0] : "adb", c);
            }
            return silent ? ':' : '?';
        }
        s_nextchar = 0;
        return static_cast<unsigned char>(c);
    }

    // plain flag; stay inside this argv element for clustered flags
    if (cur[++s_nextchar] == '\0') {
        ++optind;
        s_nextchar = 0;
    }
    return static_cast<unsigned char>(c);
}

}  // extern "C"
