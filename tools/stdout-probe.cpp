/*
 * adb-rt :: stdout-probe -- BATCH-ADB-7 section 3.
 *
 * WHAT THIS IS
 *   An x64 twin of adb's OUTPUT PATH, and nothing else. It includes adb's real `sysdeps.h`,
 *   so `printf` / `fprintf` / `fputs` / `fwrite` are redefined to `adb_printf` / `adb_fprintf`
 *   / `adb_fputs` / `adb_fwrite` exactly as they are in every adb translation unit
 *   (sysdeps.h:292-301), and it links adb's real `sysdeps_win32.cpp`. The code under test is
 *   adb's, not a reimplementation of it.
 *
 * WHY NOT THE WHOLE adb FOR x64
 *   A full x64 adb needs brotli, BoringSSL, libbase, protobuf-lite, protobuf, lz4, ssl,
 *   libusb and zstd all rebuilt for x64 -- nine third-party static libraries. The defect is
 *   in two functions in one architecture-independent C++ file. This reaches them for the cost
 *   of libbase alone. If it comes back CLEAN the narrow twin has not settled it and the full
 *   twin is the next step -- that escalation is stated in the report rather than skipped.
 *
 * WHAT IT DISCRIMINATES
 *   Each of the four wrappers is exercised SEPARATELY, because BATCH-ADB-7 section 1 candidate 3
 *   is "one wrapper broken, not all of them": `adb version` and `adb devices` do not print
 *   through the same one.
 *
 *   Everything diagnostic goes to STDERR, so it survives even when stdout is the thing that is
 *   broken. Reading a report about stdout out of stdout would be its own instrument failure.
 */

#include "sysdeps.h"

#include <errno.h>
#include <string.h>
#include <string>

// Link debt, not logic under test: sysdeps_win32.cpp reads adb_trace_mask (adb_trace.h:60).
// Pulling in adb_trace.cpp for it would drag adb_version(), AdbCloser and the fastdeploy
// protobuf into a probe about four printf wrappers.
int adb_trace_mask = 0;

int main(int argc, char* argv[]) {
    bool nonbuffered = (argc > 1 && !strcmp(argv[1], "--unbuffered"));
    bool hard_exit   = (argc > 1 && !strcmp(argv[1], "--hard-exit"));

    // Diagnostics on stderr, deliberately.
    fprintf(stderr, "[probe] stdout isatty = %d\n", unix_isatty(STDOUT_FILENO));
    fprintf(stderr, "[probe] stderr isatty = %d\n", unix_isatty(STDERR_FILENO));
    fprintf(stderr, "[probe] mode: %s\n",
            nonbuffered ? "setvbuf(_IONBF) first" : hard_exit ? "exit via _exit()" : "default");

    if (nonbuffered) {
        // This is what adb_server_main does for the DAEMON only (client/main.cpp:94-101).
        // The client path -- the one that prints `devices` -- never gets it.
        if (setvbuf(stdout, nullptr, _IONBF, 0) == -1) {
            fprintf(stderr, "[probe] setvbuf FAILED\n");
        } else {
            fprintf(stderr, "[probe] setvbuf(stdout, _IONBF) OK\n");
        }
    }

    // ---- the four wrappers, one line each, each identifiable in the output ----

    // 1. printf -> adb_printf -> adb_vfprintf. This is the shape adb_query_command() uses
    //    for `adb devices`: printf("%s", result.c_str()).
    std::string devices = "List of devices attached\n<serial>\tdevice\n";
    int r1 = printf("%s", devices.c_str());

    // 2. fprintf(stdout, ...) -> adb_fprintf
    int r2 = fprintf(stdout, "W2 via fprintf(stdout)\n");

    // 3. fputs -> adb_fputs
    int r3 = fputs("W3 via fputs\n", stdout);

    // 4. fwrite -> adb_fwrite
    const char* w4 = "W4 via fwrite\n";
    size_t r4 = fwrite(w4, 1, strlen(w4), stdout);

    // 5. stderr, through the same wrapper family, as a control: if stderr survives
    //    redirection and stdout does not, the fault is not "the wrappers".
    int r5 = fprintf(stderr, "W5 via fprintf(stderr)\n");

    fprintf(stderr, "[probe] return values: printf=%d fprintf=%d fputs=%d fwrite=%zu stderr=%d\n",
            r1, r2, r3, r4, r5);

    // Does an EXPLICIT flush work? This separates "the exit-time flush never happens" from
    // "the underlying fd is broken so the flush silently fails". It answered the first:
    // fflush returned 0/errno 0 and all 107 bytes landed.
    //
    // ⚠ OPT-IN ONLY. Once patch 0003 makes wmain() flush before _exit(), a probe that always
    // flushed here would land the bytes either way and report a pass it had manufactured.
    if (argc > 1 && !strcmp(argv[1], "--fflush")) {
        errno = 0;
        int fr = fflush(stdout);
        fprintf(stderr, "[probe] fflush(stdout) = %d, errno = %d (%s)\n",
                fr, errno, fr == 0 ? "OK" : "FAILED");
    }

    if (hard_exit) {
        // Skips CRT cleanup, so anything still sitting in stdout's buffer is lost.
        // If THIS is the only mode that loses output, candidate 1 is confirmed and the
        // question becomes which adb exit path does the same.
        fprintf(stderr, "[probe] leaving via _exit(0) -- no CRT flush\n");
        _exit(0);
    }

    fprintf(stderr, "[probe] returning from main normally (CRT will flush)\n");
    return 0;
}
