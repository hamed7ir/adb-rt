// adb-rt: basename()/dirname() for MSVC. Original work for this project.
//
// cross/msvc-posix-compat/libgen.h declared these; this pays that declaration off. libbase's
// file.cpp:22 and logging.cpp:25 include <libgen.h> unguarded, and logging.cpp calls basename.
//
// POSIX semantics, which are NOT intuitive and are what libbase expects:
//   * the argument MAY be modified (that is why it is char*, not const char*)
//   * a returned pointer may be into the argument OR into static storage
//   * basename("")   == "."      dirname("")    == "."
//   * basename("/")  == "/"      dirname("/")   == "/"
//   * trailing slashes are stripped before the basename is taken
// Windows: both '/' and '\\' count as separators, since adb handles paths in both spellings.
#include <libgen.h>

#include <string.h>

namespace {

bool IsSep(char c) { return c == '/' || c == '\\'; }

char* Dot() {
    static char dot[] = ".";
    return dot;
}

}  // namespace

extern "C" {

char* basename(char* path) {
    if (path == nullptr || *path == '\0') return Dot();

    // strip trailing separators (but a path that is ALL separators is the root)
    char* end = path + strlen(path);
    while (end > path && IsSep(end[-1])) --end;
    if (end == path) {
        static char root[] = "/";
        return root;
    }
    *end = '\0';

    char* last = end;
    while (last > path && !IsSep(last[-1])) --last;
    return last;
}

char* dirname(char* path) {
    if (path == nullptr || *path == '\0') return Dot();

    char* end = path + strlen(path);
    while (end > path && IsSep(end[-1])) --end;
    if (end == path) {
        static char root[] = "/";
        return root;
    }

    // walk back over the final component
    while (end > path && !IsSep(end[-1])) --end;
    if (end == path) return Dot();            // no separator at all -> "."

    // strip the separators between the directory and the component
    while (end > path && IsSep(end[-1])) --end;
    if (end == path) {
        static char root[] = "/";
        return root;
    }
    *end = '\0';
    return path;
}

}  // extern "C"
