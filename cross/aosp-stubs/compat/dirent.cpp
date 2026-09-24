// adb-rt: POSIX directory iteration for MSVC, over FindFirstFileW/FindNextFileW.
// Written for this project; no third-party code vendored (so no third-party licence attaches).
//
// WHY: mingw-w64 ships <dirent.h> with an implementation; the MSVC UCRT ships neither the
// header nor the code. adb uses opendir/readdir/closedir/rewinddir (client/auth.cpp,
// client/file_sync_client.cpp) AND the wide variants _wopendir/_wreaddir/_wclosedir
// (sysdeps_win32.cpp), because adb's Windows path is UTF-16 throughout.
//
// The narrow API is UTF-8, not ANSI. adb is built with -DUNICODE/-D_UNICODE and passes UTF-8
// everywhere (android::base::UTF8ToWide), so treating char* as the active code page would
// silently corrupt non-ASCII paths. Everything here converts UTF-8 <-> UTF-16 explicitly.
#include <dirent.h>

#include <windows.h>

#include <stdlib.h>
#include <string.h>
#include <wchar.h>

namespace {

struct FindState {
    HANDLE handle = INVALID_HANDLE_VALUE;
    WIN32_FIND_DATAW data{};
    bool pending = false;      // `data` holds an entry not yet returned
    wchar_t* pattern = nullptr;  // kept so rewinddir() can restart the search
};

bool StartSearch(FindState* st) {
    st->handle = FindFirstFileW(st->pattern, &st->data);
    if (st->handle == INVALID_HANDLE_VALUE) return false;
    st->pending = true;
    return true;
}

// Build "<path>\*", tolerating a trailing slash already present.
wchar_t* MakePattern(const wchar_t* path) {
    size_t n = wcslen(path);
    wchar_t* p = static_cast<wchar_t*>(malloc((n + 3) * sizeof(wchar_t)));
    if (p == nullptr) return nullptr;
    wcscpy(p, path);
    if (n > 0 && p[n - 1] != L'\\' && p[n - 1] != L'/') {
        p[n++] = L'\\';
    }
    p[n++] = L'*';
    p[n] = L'\0';
    return p;
}

unsigned char TypeOf(const WIN32_FIND_DATAW& d) {
    return (d.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? DT_DIR : DT_REG;
}

bool NextInto(FindState* st) {
    if (st->handle == INVALID_HANDLE_VALUE) return false;
    if (st->pending) {
        st->pending = false;
        return true;
    }
    if (!FindNextFileW(st->handle, &st->data)) return false;
    return true;
}

void CloseState(FindState* st) {
    if (st->handle != INVALID_HANDLE_VALUE) FindClose(st->handle);
    free(st->pattern);
}

}  // namespace

// The opaque types the header forward-declares.
struct DIR {
    FindState st;
    struct dirent ent;
};
struct _WDIR {
    FindState st;
    struct _wdirent ent;
};

extern "C" {

DIR* opendir(const char* name) {
    if (name == nullptr) return nullptr;
    int wn = MultiByteToWideChar(CP_UTF8, 0, name, -1, nullptr, 0);
    if (wn <= 0) return nullptr;
    wchar_t* wide = static_cast<wchar_t*>(malloc(wn * sizeof(wchar_t)));
    if (wide == nullptr) return nullptr;
    MultiByteToWideChar(CP_UTF8, 0, name, -1, wide, wn);

    DIR* d = static_cast<DIR*>(calloc(1, sizeof(DIR)));
    if (d == nullptr) {
        free(wide);
        return nullptr;
    }
    d->st.pattern = MakePattern(wide);
    free(wide);
    if (d->st.pattern == nullptr || !StartSearch(&d->st)) {
        free(d->st.pattern);
        free(d);
        return nullptr;
    }
    return d;
}

struct dirent* readdir(DIR* dirp) {
    if (dirp == nullptr || !NextInto(&dirp->st)) return nullptr;
    int n = WideCharToMultiByte(CP_UTF8, 0, dirp->st.data.cFileName, -1, dirp->ent.d_name,
                                sizeof(dirp->ent.d_name), nullptr, nullptr);
    if (n <= 0) {
        dirp->ent.d_name[0] = '\0';
        n = 1;
    }
    dirp->ent.d_ino = 0;
    dirp->ent.d_type = TypeOf(dirp->st.data);
    dirp->ent.d_reclen = static_cast<unsigned short>(sizeof(struct dirent));
    return &dirp->ent;
}

int closedir(DIR* dirp) {
    if (dirp == nullptr) return -1;
    CloseState(&dirp->st);
    free(dirp);
    return 0;
}

void rewinddir(DIR* dirp) {
    if (dirp == nullptr) return;
    if (dirp->st.handle != INVALID_HANDLE_VALUE) FindClose(dirp->st.handle);
    dirp->st.handle = INVALID_HANDLE_VALUE;
    dirp->st.pending = false;
    StartSearch(&dirp->st);
}

_WDIR* _wopendir(const wchar_t* name) {
    if (name == nullptr) return nullptr;
    _WDIR* d = static_cast<_WDIR*>(calloc(1, sizeof(_WDIR)));
    if (d == nullptr) return nullptr;
    d->st.pattern = MakePattern(name);
    if (d->st.pattern == nullptr || !StartSearch(&d->st)) {
        free(d->st.pattern);
        free(d);
        return nullptr;
    }
    return d;
}

struct _wdirent* _wreaddir(_WDIR* dirp) {
    if (dirp == nullptr || !NextInto(&dirp->st)) return nullptr;
    wcsncpy(dirp->ent.d_name, dirp->st.data.cFileName,
            sizeof(dirp->ent.d_name) / sizeof(wchar_t) - 1);
    dirp->ent.d_name[sizeof(dirp->ent.d_name) / sizeof(wchar_t) - 1] = L'\0';
    dirp->ent.d_ino = 0;
    dirp->ent.d_namlen = static_cast<unsigned short>(wcslen(dirp->ent.d_name));
    dirp->ent.d_reclen = static_cast<unsigned short>(sizeof(struct _wdirent));
    return &dirp->ent;
}

int _wclosedir(_WDIR* dirp) {
    if (dirp == nullptr) return -1;
    CloseState(&dirp->st);
    free(dirp);
    return 0;
}

void _wrewinddir(_WDIR* dirp) {
    if (dirp == nullptr) return;
    if (dirp->st.handle != INVALID_HANDLE_VALUE) FindClose(dirp->st.handle);
    dirp->st.handle = INVALID_HANDLE_VALUE;
    dirp->st.pending = false;
    StartSearch(&dirp->st);
}

}  // extern "C"
