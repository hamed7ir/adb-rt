// adb-rt: nftw() over our dirent implementation. Original work for this project.
//
// cross/msvc-posix-compat/ftw.h declared it; this pays that off. libbase's file.cpp:200 calls
// nftw(path, callback, 128, FTW_DEPTH|FTW_MOUNT|FTW_PHYS) to delete a TemporaryDir recursively.
//
// Supports what that call site needs and no more: FTW_DEPTH (post-order, so a directory is
// reported AFTER its contents -- required for recursive delete), FTW_PHYS (do not follow
// links; we never follow reparse points anyway) and FTW_MOUNT (single filesystem; a no-op
// here). Reports FTW_F for files and FTW_D/FTW_DP for directories.
#include <ftw.h>

#include <dirent.h>
#include <string.h>
#include <sys/stat.h>

#include <string>

namespace {

int WalkOne(const std::string& path, int (*fn)(const char*, const struct stat*, int, struct FTW*),
            int flags, int level, int base_offset) {
    struct stat st;
    const bool have_stat = (stat(path.c_str(), &st) == 0);
    const bool is_dir = have_stat && S_ISDIR(st.st_mode);
    struct FTW ftw_info;
    ftw_info.base = base_offset;
    ftw_info.level = level;

    // pre-order for a directory unless FTW_DEPTH was asked for
    if (is_dir && !(flags & FTW_DEPTH)) {
        const int rc = fn(path.c_str(), have_stat ? &st : nullptr, FTW_D, &ftw_info);
        if (rc != 0) return rc;
    }

    if (is_dir) {
        DIR* d = opendir(path.c_str());
        if (d != nullptr) {
            for (struct dirent* e = readdir(d); e != nullptr; e = readdir(d)) {
                if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
                std::string child = path + "/" + e->d_name;
                const int rc = WalkOne(child, fn, flags, level + 1,
                                       static_cast<int>(path.size()) + 1);
                if (rc != 0) {
                    closedir(d);
                    return rc;
                }
            }
            closedir(d);
        }
    }

    const int type = is_dir ? ((flags & FTW_DEPTH) ? FTW_DP : FTW_D) : (have_stat ? FTW_F : FTW_NS);
    if (is_dir && !(flags & FTW_DEPTH)) return 0;   // already reported pre-order
    return fn(path.c_str(), have_stat ? &st : nullptr, type, &ftw_info);
}

}  // namespace

extern "C" {

int nftw(const char* dirpath, int (*fn)(const char*, const struct stat*, int, struct FTW*),
         int /*nopenfd*/, int flags) {
    if (dirpath == nullptr || fn == nullptr) return -1;
    return WalkOne(std::string(dirpath), fn, flags, 0, 0);
}

// Plain ftw() is DELIBERATELY NOT IMPLEMENTED: nothing in this build calls it (only nftw,
// from libbase file.cpp:200). An undefined symbol is a more honest failure than a wrapper
// written blind. It is declared in ftw.h; if a future source needs it, the linker will say so.

}  // extern "C"
