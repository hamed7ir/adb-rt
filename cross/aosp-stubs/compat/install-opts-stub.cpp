// adb-rt: stand-ins for client/fastdeploy.cpp and client/incremental_utils.cpp.
//
// WHY. These two sources are the LAST blockers to a linked adb.exe, and each is blocked on a
// large AOSP library we do not have:
//   client/fastdeploy.cpp        -> libandroidfw (androidfw/ResourceTypes.h), which itself
//                                   pulls libutils and libziparchive
//   client/incremental_utils.cpp -> libziparchive (ziparchive/zip_archive.h), which pulls libz
// Their symbols are referenced UNCONDITIONALLY by client/commandline.cpp and
// client/adb_install.cpp, so they cannot simply be dropped -- the Q1 lesson.
//
// ⚠⚠ BEHAVIOURAL CONSEQUENCE, STATED PLAINLY:
//        `adb install --fastdeploy`  and  `adb install --incremental`  DO NOT WORK.
// Ordinary `adb install` is unaffected (adb_install.cpp compiles and links normally), as are
// CNXN, AUTH, shell, push/pull and forward -- which are ADB-2's actual deliverable.
//
// Every function fails loudly rather than returning a plausible value. Returning, say, an
// empty APKMetaData would make adb proceed and then corrupt an install; returning a bad fd
// makes it stop. This is the same rule as the USB stub.
#include "client/fastdeploy.h"
#include "client/incremental_utils.h"

#include <stdio.h>

namespace {
void Unavailable(const char* what) {
    fprintf(stderr,
            "adb: %s is not available in this build (adb-rt armv7-windows-msvc):\n"
            "adb:   libandroidfw / libziparchive are not built for ARM32.\n"
            "adb:   use plain `adb install` instead.\n",
            what);
    fflush(stderr);
}
}  // namespace

// ---- client/fastdeploy.h ----
void fastdeploy_set_agent_update_strategy(FastDeploy_AgentUpdateStrategy) {}

int get_device_api_level() {
    // Used by the fastdeploy path to decide agent compatibility. -1 means "unknown", which is
    // what fastdeploy treats as "do not proceed".
    return -1;
}

std::optional<com::android::fastdeploy::APKMetaData> extract_metadata(const char*) {
    Unavailable("adb install --fastdeploy");
    return std::nullopt;
}

unique_fd install_patch(int, const char**) {
    Unavailable("adb install --fastdeploy");
    return unique_fd();
}

unique_fd apply_patch_on_device(const char*) {
    Unavailable("adb install --fastdeploy");
    return unique_fd();
}

int stream_patch(const char*, com::android::fastdeploy::APKMetaData, unique_fd) {
    Unavailable("adb install --fastdeploy");
    return -1;
}

// ---- client/incremental_utils.h ----
namespace incremental {

std::vector<int32_t> PriorityBlocksForFile(const std::string&, borrowed_fd, Size) {
    Unavailable("adb install --incremental");
    return {};
}

Size verity_tree_blocks_for_file(Size) { return 0; }

Size verity_tree_size_for_file(Size) { return 0; }

std::pair<std::vector<char>, int32_t> read_id_sig_headers(borrowed_fd) {
    Unavailable("adb install --incremental");
    return {{}, -1};
}

std::pair<off64_t, ssize_t> skip_id_sig_headers(borrowed_fd) {
    Unavailable("adb install --incremental");
    return {0, -1};
}

}  // namespace incremental
