# NOTICE — third-party components and locally-written compatibility code

`adb-rt` builds AOSP `adb` for `armv7-pc-windows-msvc`. It **vendors no third-party source at all**: nothing
under `deps/` is committed here. `scripts/fetch-deps.sh` reconstructs it from pinned public
refs. Every tree it produces is byte-identical to its pinned tarball or commit **as fetched**,
verified by re-extract-and-diff — and the script then applies the three patches below to
`adb-35.0.2` and `libusb-1.0.28`, which is the only thing that changes them. The three source changes are carried as **patch files** under `patches/`,
never applied in place in a published tree — so the patch count stays visible and honest.

The `deps/...` paths in the tables below are where that script puts each component.

## Third-party sources (unmodified, under their own licences)

| component | version / pin | licence | where |
|---|---|---|---|
| AOSP `adb` | platform-tools 35.0.2, commit `ce9ea51f30f69f7560db692f7cb4d5d5502c3653` | Apache-2.0 | `deps/adb-35.0.2` |
| AOSP `libbase` | platform-tools 35.0.2, commit `328768fabb054387ad7f64c984d4afcea70d25c9` | Apache-2.0 | `deps/libbase` |
| BoringSSL | rev `a0cb538b0d0d08371d3bd5712bbc8d474d28090a` | Apache-2.0 / OpenSSL / ISC (see its own `LICENSE`) | `deps/boringssl-pinned` |
| Protocol Buffers | 3.21.12 | BSD-3-Clause | `deps/protobuf-3.21.12` |

⚠ **libusb (1.0.28, listed under *Further components* below) is LGPL-2.1-or-later.** It is
used here as a **static** library. Anyone redistributing
a linked `adb.exe` must satisfy the LGPL's relinking provision (ship objects or an equivalent
mechanism), or link libusb dynamically. Flagged because this repo is intended for publication;
AOSP's own Windows adb has the same obligation.

## Source patches

| patch | scope | status |
|---|---|---|
| `patches/0001-adb-from_chars-portable-iterators.patch` | `adb_utils.h`, 3 lines in `ParseUint` | **UPSTREAMABLE TO AOSP** — fixes reliance on `string_view::const_iterator` being `const char*`, which the standard leaves implementation-defined |
| `patches/0002-libusb-backport-windows-hotplug.patch` | libusb 1.0.28: adds `os/windows_hotplug.c` and `os/windows_hotplug.h`, and modifies 5 existing files (`core.c`, `libusbi.h`, `os/windows_common.{c,h}`, `os/windows_winusb.c`) | **BACKPORT** from upstream libusb commit `5b870b6`. Stock 1.0.28 has no Windows hotplug, and adb's `client/usb_libusb.cpp` `LOG(FATAL)`s when `libusb_hotplug_register_callback` fails. Carries libusb's own LGPL-2.1-or-later licence, not this repository's |
| `patches/0003-adb-flush-stdio-before-_exit-in-wmain.patch` | `sysdeps_win32.cpp`, 1 line in `wmain` | `_exit()` skips the CRT's stdio flush, so adb wrote **zero bytes** whenever stdout was a pipe rather than a console. Also upstreamable |

**Patch count: 3.** Two to AOSP, one to libusb. The report says 3.

## Locally-written compatibility code — original work, no third-party code vendored

All files below were **written for this project**. They are not derived from, and contain no code
copied from, mingw-w64, Cygwin, the BSD `getopt`, Toni Rönkkö's `dirent.h`, or any other existing
implementation. They therefore carry **this repository's licence** and add **no third-party
licence obligation**.

This was a deliberate choice: vendoring a third-party single-header implementation would have been
quicker, but it would attach another licence to a repo meant for publication, for a few hundred
lines that are straightforward to write directly against Win32.

| file | what it provides | why it is needed |
|---|---|---|
| `cross/msvc-posix-compat/*` | `unistd.h`, `dirent.h`, `getopt.h`, `utime.h`, `signal.h`, `stdio.h`, `sys/{cdefs,param,time,types,stat}.h`, `winsock2.h`, `ws2tcpip.h`, `mswsock.h` | AOSP builds Windows adb with **mingw-w64**; MSVC's UCRT lacks these headers and symbols. Headers that extend rather than replace use `#include_next`. |
| `cross/aosp-stubs/cutils/sockets.h` | the `ANDROID_SOCKET_NAMESPACE_*` enum only | measured: the host link graph uses **no** libcutils function |
| `cross/aosp-stubs/compat/asprintf.cpp` | `asprintf`, `vasprintf` | GNU extensions; mingw has them, UCRT does not |
| `cross/aosp-stubs/compat/getopt.cpp` | `getopt`, `optind`, `optarg`, `opterr`, `optopt` | mingw ships a real `getopt`; UCRT does not. `getopt_long` is declared but **deliberately unimplemented** — no source in our build set uses it, and an undefined symbol is a more honest failure than a subtly wrong implementation |
| `cross/aosp-stubs/compat/dirent.cpp` | `opendir`/`readdir`/`closedir`/`rewinddir` and `_wopendir`/`_wreaddir`/`_wclosedir`/`_wrewinddir`, over `FindFirstFileW` | same gap; adb's Windows path is UTF-16 and needs the wide variants. The narrow API is **UTF-8**, not ANSI, matching adb's own convention |
| `cross/aosp-stubs/compat/mdns-stub.cpp` | the `adb_mdns.h` surface as honest no-ops | mDNS cannot be compiled out by a flag (`ADB_MDNS` is a *runtime* env var). Removes `libmdnssd` and both openscreen modules. **Cost: no mDNS discovery.** See READING T4 |
| `cross/clang-cl-arm-shim.h` | `_CountLeadingZeros`, `_CountLeadingZeros64` | MSVC's `<bit>` calls these in its `_M_ARM` branch with no `!__clang__` guard |
| `cross/adb-stl-gaps.h` | force-includes `<array>` | libc++ supplies it transitively via `<string_view>`; the MSVC STL does not |
| `cross/*.cmake`, `cross/libusb-CMakeLists.txt`, `scripts/*.sh` | build infrastructure | — |

## Toolchain (not redistributed here)

rt2 = LLVM 23.1.1-rt2 (Apache-2.0 WITH LLVM-exception) · MSVC 14.44.35207 and Windows SDK
10.0.19041.0 (Microsoft, used under their own terms, not redistributed).

---

# Further components

## Further third-party sources (unmodified, under their own licences)

| component | version / pin | licence | where |
|---|---|---|---|
| AOSP `libdiagnose_usb` | `platform/system/core` commit `90e4908e776d2be9b26b87af649e63e4208cf085`, 2 files, each sha256-pinned | Apache-2.0 | `deps/libdiagnose_usb` |
| AOSP `libcrypto_utils` | `platform/system/core` commit `90e4908e776d2be9b26b87af649e63e4208cf085`, 2 files, each sha256-pinned | Apache-2.0 | `deps/libcrypto_utils` |
| **libusb** | **1.0.28** (was 1.0.27) · sha256 `966bb0d231f94a474eaae2e67da5ec844d3527a1f386456394ff432580634b29` | **LGPL-2.1-or-later** | `deps/libusb-1.0.28` |
| lz4 | 1.9.4 | BSD-2-Clause (the `lib/` directory; the CLI is GPL-2.0 and is not built) | `deps/lz4-1.9.4` |
| Brotli | 1.1.0 | MIT | `deps/brotli-1.1.0` |
| Zstandard | 1.5.6 | BSD-3-Clause / GPL-2.0 dual (the `lib/` directory) | `deps/zstd-1.5.6` |

⚠ **The libusb LGPL obligation carries forward to 1.0.28 and is unchanged**: it is linked
**statically** into `adb.exe`, so anyone redistributing the binary must satisfy the relinking
provision or link libusb dynamically.

## Further locally-written compatibility code — original work, no third-party code vendored

| file | what it provides |
|---|---|
| `cross/aosp-stubs/android/log.h` | the liblog API surface libbase's `logging.cpp` needs |
| `cross/aosp-stubs/compat/liblog-stub.cpp` | 10 `__android_log_*` entry points. **Writes to stderr** — it does not swallow output |
| `cross/aosp-stubs/compat/clock.cpp` | `clock_gettime` over Win32 (in a `.cpp` so `<windows.h>` cannot poison every TU) |
| `cross/aosp-stubs/compat/libgen.cpp` | POSIX `basename`/`dirname` |
| `cross/aosp-stubs/compat/ftw.cpp` | `nftw` over our `dirent`. Plain `ftw()` is deliberately **not** implemented |
| `cross/aosp-stubs/compat/usb-windows-stub.cpp` | the 7 global `usb_*` entry points. ⚠ **USB requires `ADB_LIBUSB=1` in this build** |
| `cross/aosp-stubs/compat/install-opts-stub.cpp` | fastdeploy + incremental symbols. ⚠ **`adb install --fastdeploy` and `--incremental` do not work** |
| `cross/msvc-posix-compat/{time,string,limits,libgen,ftw,strings}.h` | further mingw-gap headers |
| `cross/canary/canary.cpp` | the three-line canary that triggers `/failifmismatch` early |
| `build/gen-include/{platform_tools_version.h,build/version.h}` | the two headers Soong generates |

All are original work for this project, carry this repository's licence, and add **no
third-party licence obligation**.

## Deliberate functional omissions in the linked `adb.exe`

Stated here because a user of the binary needs to know, not only a reader of the build:

1. **mDNS discovery** — `adb mdns check|services` and `adb pair` *discovery*. The SPAKE2 pairing
   crypto is present in our BoringSSL; only discovery is stubbed.
2. **`adb install --fastdeploy` / `--incremental`** — `libandroidfw` / `libziparchive` are not
   built for ARM32. Plain `adb install` is unaffected.
3. **USB requires `ADB_LIBUSB=1`** — the AdbWinApi backend is not built; libusb 1.0.28 is.
