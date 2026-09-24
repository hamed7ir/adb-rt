# UPSTREAM — what this repository builds, and whose work it is

`adb-rt` is **build infrastructure for AOSP's Android Debug Bridge**. It is not a fork of AOSP
and it contains no upstream source. [`scripts/fetch-deps.sh`](scripts/fetch-deps.sh)
reconstructs every component below from its own project, **verifies each one against the pin
recorded here — a sha256 for each tarball, a commit SHA for each git component — and refuses to
continue on a mismatch.**

## Components

| component | upstream | version | pinned by | licence | linkage | patches from here |
|---|---|---|---|---|---|---|
| **adb** | [AOSP `packages/modules/adb`](https://android.googlesource.com/platform/packages/modules/adb) | **platform-tools 35.0.2** | commit SHA | Apache-2.0 | compiled into `adb.exe` | **2** |
| **libbase** | [AOSP `system/libbase`](https://android.googlesource.com/platform/system/libbase) | platform-tools 35.0.2 | commit SHA | Apache-2.0 | static | 0 |
| **libdiagnose_usb** | [AOSP `system/core`](https://android.googlesource.com/platform/system/core) | platform-tools 35.0.2 | commit SHA + per-file sha256 | Apache-2.0 | static | 0 |
| **libcrypto_utils** | [AOSP `system/core`](https://android.googlesource.com/platform/system/core) | platform-tools 35.0.2 | commit SHA + per-file sha256 | Apache-2.0 | static | 0 |
| **BoringSSL** | [Google](https://boringssl.googlesource.com/boringssl) | the revision AOSP pins for this drop | commit SHA | Apache-2.0 / OpenSSL / ISC | static | 0 |
| **libusb** | [libusb/libusb](https://github.com/libusb/libusb) | **1.0.28** | tarball sha256 | **LGPL-2.1-or-later** | **static** ← see the notices | **1** |
| **Protocol Buffers** | [protocolbuffers/protobuf](https://github.com/protocolbuffers/protobuf) | 3.21.12 | tarball sha256 | BSD-3-Clause | static | 0 |
| **Brotli** | [google/brotli](https://github.com/google/brotli) | 1.1.0 | tarball sha256 | MIT | static | 0 |
| **lz4** | [lz4/lz4](https://github.com/lz4/lz4) | 1.9.4 | tarball sha256 | BSD-2-Clause (`lib/`) | static | 0 |
| **Zstandard** | [facebook/zstd](https://github.com/facebook/zstd) | 1.5.6 | tarball sha256 | BSD-3-Clause / GPL-2.0 dual (`lib/`) | static | 0 |

**Total patches from this repository: 3** — two to adb, one to libusb. Every one is a file in
`patches/`, applied by the fetch script to the fetched tree and never vendored, so `ls patches/`
stays the honest count. Under Apache-2.0 §4(b): **the AOSP files are modified**, by patches 0001
and 0003, and both are named below.

Only `lib/` is built from lz4 and zstd. lz4's command-line tool is GPL-2.0 and **is not built**;
zstd's test tree is not even extracted.

### The exact pins

**AOSP**, all three repositories at tag `platform-tools-35.0.2`, under
`https://android.googlesource.com/platform`:

| repository | commit |
|---|---|
| `packages/modules/adb` | `ce9ea51f30f69f7560db692f7cb4d5d5502c3653` |
| `system/libbase` | `328768fabb054387ad7f64c984d4afcea70d25c9` |
| `system/core` | `90e4908e776d2be9b26b87af649e63e4208cf085` |

⚠ Those are the **commit** SHAs the tag points at, not the tag objects.
`platform-tools-35.0.2` is an *annotated* tag, so `git ls-remote <url> refs/tags/<tag>` returns
the tag object's sha — which `git rev-parse HEAD` in a clone will never equal. Peel it with
`refs/tags/<tag>^{}`.

⚠ The AOSP components are pinned by **commit, not by archive tarball**, deliberately.
`android.googlesource.com/<repo>/+archive/<ref>.tar.gz` regenerates the tarball on every
request: two fetches of the same archive seconds apart return **different sha256** values, and
differ after decompression too, so even a content pin cannot hold. The adb repository's archive
endpoint answers 503 outright.

**The two `system/core` libraries** are four files, not whole trees — `system/core` is large
and almost entirely irrelevant here, so the fetch script takes only what adb links and pins
each file by **content hash** as well as by the commit above:

| file | sha256 |
|---|---|
| `diagnose_usb/diagnose_usb.cpp` | `0c96b58e230a6c8dc537391893d40a3e848016632808cc7313f25e84ab880b47` |
| `diagnose_usb/include/diagnose_usb.h` | `a77d70fd616d4c70ba1790253bf20fa0e3ae3ccf02eccc8171caff2c3af3f03a` |
| `libcrypto_utils/android_pubkey.cpp` | `31068871b013c250c8cc3595560d415cdc4256c8bda4c9c2401d93835b86a9c5` |
| `libcrypto_utils/include/crypto_utils/android_pubkey.h` | `5e04b026c14f0fe94e2403008a1819dd9796b0afffef5ceef953411f1bee66a0` |

It is `android_pubkey.`**`cpp`** at this tag, not `.c` — the file was converted to C++ upstream.

**BoringSSL** — `https://boringssl.googlesource.com/boringssl`, commit
`a0cb538b0d0d08371d3bd5712bbc8d474d28090a`. This is the revision AOSP itself pins for this
drop, read from `external/boringssl/BORINGSSL_REVISION`; it is chosen over `main` because adb
35.0.2 is written against that API and BoringSSL churns. There is no tag on it.

**Tarballs**, each verified by sha256:

| component | URL | sha256 |
|---|---|---|
| libusb 1.0.28 | `https://github.com/libusb/libusb/releases/download/v1.0.28/libusb-1.0.28.tar.bz2` | `966bb0d231f94a474eaae2e67da5ec844d3527a1f386456394ff432580634b29` |
| protobuf 3.21.12 | `https://github.com/protocolbuffers/protobuf/releases/download/v21.12/protobuf-cpp-3.21.12.tar.gz` | `4eab9b524aa5913c6fffb20b2a8abf5ef7f95a80bc0701f3a6dbb4c607f73460` |
| Brotli 1.1.0 | `https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz` | `e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff` |
| lz4 1.9.4 | `https://github.com/lz4/lz4/archive/refs/tags/v1.9.4.tar.gz` | `0b0e3aa07c8c063ddf40b082bdf7e37a1562bda40a0ff5272957f3e987e0e54b` |
| zstd 1.5.6 | `https://github.com/facebook/zstd/archive/refs/tags/v1.5.6.tar.gz` | `30f35f71c1203369dc979ecde0400ffea93c27391bfd2ac5a9715d2173d92ff7` |

The protobuf entry is the **release asset**, not the tag archive; for zstd it is the **tag
archive**, not the release asset. They are different tarballs with different hashes, and the
ones named here are the ones these hashes belong to. Every hash above was re-fetched from the
URL written beside it and re-hashed before it was recorded.

libusb **1.0.28, not 1.0.27**: adb 35.0.2's `client/usb_libusb.cpp` calls the SuperSpeed+ BOS
descriptor API, which 1.0.27 does not declare.

## Patches — 3

| patch | applies to | what it is |
|---|---|---|
| [`0001-adb-from_chars-portable-iterators.patch`](patches/0001-adb-from_chars-portable-iterators.patch) | adb | **upstreamable to AOSP.** `std::from_chars(str.begin(), str.end(), …)` on a `string_view` compiles only where that iterator happens to be `const char*`; the standard leaves the type implementation-defined |
| [`0002-libusb-backport-windows-hotplug.patch`](patches/0002-libusb-backport-windows-hotplug.patch) | libusb | **upstream libusb's own code**, backported from commit `5b870b6`. It carries **libusb's LGPL-2.1-or-later**, not this repository's licence. Stock 1.0.28 has no Windows hotplug at all, and adb `LOG(FATAL)`s when `libusb_hotplug_register_callback` fails |
| [`0003-adb-flush-stdio-before-_exit-in-wmain.patch`](patches/0003-adb-flush-stdio-before-_exit-in-wmain.patch) | adb | **upstreamable to AOSP.** `_exit()` skips the CRT's stdio flush, so adb writes **zero bytes** whenever stdout is a pipe rather than a console — correct in a terminal, empty to every tool that reads it |

## How the pins are verified

`scripts/fetch-deps.sh` compares each git checkout's `HEAD` to the commit SHA above, each
tarball to its sha256, and each of the four single AOSP source files to its own content hash;
it stops on any mismatch. It **self-tests the hash checker before trusting it** — hashing a
known vector, then confirming a one-byte change hashes differently — and exits 2 if either
check fails. Git components are cloned with `core.autocrlf=false`, so the tree you get is
byte-identical to the one these binaries were built from, which was verified by hashing
individual libbase sources against the built-from tree.

## What in this repository is not upstream's

`cross/msvc-posix-compat/` (the mingw-to-MSVC header gap), `cross/aosp-stubs/` (liblog, mDNS,
fastdeploy and the compat implementations), the CMake toolchain files, `scripts/`, `config.sh`,
`driver/` and `tools/`. All of it was **written for this project** and contains no code copied
from mingw-w64, Cygwin, the BSD `getopt`, or any other existing implementation — it therefore
carries this repository's licence and adds no third-party licence obligation.
[`NOTICE.md`](NOTICE.md) has the file-by-file table and the reason each file exists.

## The obligation that needs care

⚠ **libusb is LGPL-2.1-or-later and is linked statically into `adb.exe`.** Static linking does
not remove the relinking requirement; publishing the complete corresponding source and the
build scripts is how it is met here. [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) sets
out exactly how, and [`COPYING.LGPL-2.1`](COPYING.LGPL-2.1) is libusb's licence text.

## Toolchain — used, not redistributed

**rt2** — **LLVM 23.1.1 plus a small set of patches** this target still needs upstream, built
as its own project and published at **<https://github.com/hamed7ir/llvm-rt1>**. Base: `llvmorg-23.1.1`, whose source tarball
sha256 `ebe9be46fe8756d58c5b198ffad0fa2a766257add81a4dc52179bfacc7888ee6` was verified before
that build. Licence: **Apache-2.0 WITH LLVM-exception**, and because it is a *modified* LLVM,
its own repository is where the modified source lives — not here.

The binaries these repos were built with are identified by sha256 in `config.sh`, not by version
string alone, because an unrelated LLVM 18.1.8 lives one character away on the original build
machine and would build everything silently and wrongly.

MSVC toolset 14.44.35207 and Windows SDK 10.0.19041.0: Microsoft, under their own terms.
**Nothing in this paragraph is redistributed here.**
