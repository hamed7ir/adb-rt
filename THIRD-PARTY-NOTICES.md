# THIRD-PARTY NOTICES — adb-rt

`adb-rt` is build infrastructure. It **vendors no third-party source**: nothing under `deps/` is
committed here. `scripts/fetch-deps.sh` reconstructs it from pinned, public refs — a sha256 for
every tarball, a commit SHA for every git component — and refuses to continue if a pin does not
match.

`NOTICE.md` is the longer companion to this file: it lists every locally-written compatibility
file, what gap each closes, and the functional omissions in the linked binary.

## Components

| component | version / pin | licence | linkage |
|---|---|---|---|
| AOSP `adb` | platform-tools **35.0.2**, commit `ce9ea51f30f69f7560db692f7cb4d5d5502c3653` | **Apache-2.0** | compiled into `adb.exe` |
| AOSP `libbase` | same tag, commit `328768fabb054387ad7f64c984d4afcea70d25c9` | Apache-2.0 | static |
| AOSP `libdiagnose_usb`, `libcrypto_utils` | `platform/system/core` @ `90e4908e776d2be9b26b87af649e63e4208cf085` | Apache-2.0 | static |
| BoringSSL | `a0cb538b0d0d08371d3bd5712bbc8d474d28090a` — the revision AOSP itself pins for this drop | Apache-2.0 / OpenSSL / ISC (see its own `LICENSE`) | static |
| **libusb** | **1.0.28**, sha256 `966bb0d231f94a474eaae2e67da5ec844d3527a1f386456394ff432580634b29` | **LGPL-2.1-or-later** | **static** ← the one that needs care |
| Protocol Buffers | 3.21.12, sha256 `4eab9b52…3460` | BSD-3-Clause | static |
| Brotli | 1.1.0, sha256 `e720a6ca…13ff` | MIT | static |
| lz4 | 1.9.4, sha256 `0b0e3aa0…e54b` | BSD-2-Clause (the `lib/` directory; the CLI is GPL-2.0 and is **not** built) | static |
| Zstandard | 1.5.6, sha256 `30f35f71…2ff7` | BSD-3-Clause / GPL-2.0 dual (the `lib/` directory) | static |

## ⚠ libusb is LGPL-2.1-or-later and is STATICALLY LINKED into `adb.exe`

This is the obligation in this repository that needs stating rather than implying.

**Static linking does not remove the LGPL's relinking requirement.** LGPL-2.1 §6 lets a work be
distributed as a statically linked binary provided the recipient can relink it against a
modified libusb, and §6(a) names one way of doing that: supply the complete corresponding
source together with whatever is needed to rebuild.

**That is how it is met here.** This repository publishes:

- the **complete build** — `scripts/`, `cross/`, `config.sh`, the CMake toolchain files and the
  response-file templates — everything used to produce the shipped binary
- **`scripts/fetch-deps.sh`**, which pins libusb 1.0.28 by sha256 and every other component by
  sha256 or commit SHA, so the corresponding source is exactly recoverable
- **all three patches**, including `patches/0002-libusb-backport-windows-hotplug.patch`, which
  is the only change made to libusb and carries **libusb's own licence**, not this
  repository's — it is a backport of upstream libusb commit `5b870b6`, not new work

Anyone may therefore substitute their own libusb, run the same scripts, and produce their own
`adb.exe`. AOSP's own Windows adb carries the same obligation.

The libusb licence text is reproduced verbatim at [`COPYING.LGPL-2.1`](COPYING.LGPL-2.1).

## Source patches — 3, each listed rather than folded into a tree

| patch | applies to | what it is |
|---|---|---|
| `0001-adb-from_chars-portable-iterators.patch` | adb | **upstreamable to AOSP** — `std::from_chars` on `string_view::begin()/end()` only compiles where that iterator happens to be `const char*` |
| `0002-libusb-backport-windows-hotplug.patch` | libusb | **upstream code**, backported from libusb `5b870b6`. LGPL-2.1-or-later, like the rest of libusb |
| `0003-adb-flush-stdio-before-_exit-in-wmain.patch` | adb | **upstreamable to AOSP** — `_exit()` skips the CRT's stdio flush, so adb wrote zero bytes whenever stdout was a pipe |

`scripts/fetch-deps.sh` applies them to the fetched trees. They are never applied in place in a
published tree, so `ls patches/` stays the honest count. Under Apache-2.0 §4(b): the AOSP files
**are** modified, by patches 0001 and 0003, and both are listed above.

## Files added by this project

The `cross/msvc-posix-compat/` headers and the `cross/aosp-stubs/` sources were **written for
this project** — see `NOTICE.md` for the file-by-file table and the gap each closes. They are
not derived from mingw-w64, Cygwin, the BSD `getopt`, or any other existing implementation, so
they carry this repository's licence and add **no third-party licence obligation**.

## Toolchain — used, not redistributed

| | |
|---|---|
| **rt2** — LLVM 23.1.1-rt2 | Apache-2.0 WITH LLVM-exception |
| MSVC toolset 14.44.35207, Windows SDK 10.0.19041.0 | Microsoft, used under their own terms |

## Reference binary deliberately NOT redistributed

A 2013 third-party ARM32 `adb` (`adb-1.0.31-winarm32.zip`, from `files.open-rt.party/Software/`)
was used as an instrument during this port, to establish that a Surface RT can drive a modern
phone at all before anything was built. Its licence and provenance are unknown, so it is **not**
in this repository and not in any release from it.
