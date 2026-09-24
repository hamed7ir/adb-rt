# adb-rt

> **Upstream: [Android Debug Bridge](https://android.googlesource.com/platform/packages/modules/adb)
> (AOSP), tag `platform-tools-35.0.2`. Patches applied here: 3** — two to adb, one to libusb.
> Build infrastructure only; no upstream source is included. `scripts/fetch-deps.sh` verifies
> every pin. See [`UPSTREAM.md`](UPSTREAM.md).

AOSP adb for 32-bit ARM Windows (`armv7-pc-windows-msvc`). It runs on **Windows RT 8.1**, over
**USB and over Wi-Fi**.

Tested on a Surface RT (Tegra 3) with three phones from three vendors: **Volla Phone Quintus**,
**Google Pixel 9 Pro XL** and **BlackBerry Priv**. `devices`, `shell`, `push`, `forward`,
`reverse`, `pair` and `connect` work.

`adb.exe` is a single static binary with no UCRT dependency.

## USB

- **`ADB_LIBUSB=1` must be set.**
- File-transfer and PTP modes need one registry value on RT: run `tools\adb-usb-check.cmd`, then
  `tools\adb-usb-bind.cmd` as administrator, then replug.
- A phone without a WinUSB descriptor needs a **signed** INF; RT refuses unsigned ones. See
  [`driver/README.md`](driver/README.md).

## Wi-Fi

```
adb pair <ip>:<pairing-port> <code>
adb connect <ip>:<port>
```

Type the ports shown on the phone's Wireless debugging screen; there is no automatic discovery.
`adb tcpip 5555` also works.

## Patches

| | |
|---|---|
| `0001` | adb: `std::from_chars` iterator portability |
| `0002` | libusb 1.0.28: Windows hotplug, backported from upstream libusb `5b870b6` |
| `0003` | adb: flush stdio before `_exit()`, so output reaches a pipe |

## Not built

- mDNS discovery
- `adb install --fastdeploy` and `--incremental`

`adb pull` is untested.

## Build

Set these in [`config.sh`](config.sh) or export them. The same names work in all three `-rt` repos.

| variable | value |
|---|---|
| `RT2` | LLVM 23.1.1-rt2 `bin` directory |
| `VCTOOLS` | MSVC 14.44.35207 (14.51 dropped ARM32) |
| `WINSDK`, `WINSDKVER` | Windows SDK 10.0.19041.0 (the last with ARM32 libraries) |
| `CMAKE`, `NINJA` | native Windows builds, not MSYS2's; cmake 3.31.6 |

From an MSYS2 shell:

```sh
sh scripts/fetch-deps.sh
sh scripts/gen-rsp.sh
sh scripts/rebuild-all-mt.sh
sh scripts/build-libusb.sh
sh scripts/build-libbase.sh
sh scripts/build-compression.sh
sh scripts/build-aosp-small.sh
sh scripts/build-shims.sh
sh scripts/gen-protos.sh
sh scripts/compile-adb-objects.sh
sh scripts/compile-extras.sh
sh scripts/link-adb.sh
```

Absolute build paths are embedded in `adb.exe`.

## Licence

**Copyright (c) 2026 hamed7ir** for the files this repository adds, under Apache-2.0 —
[`LICENSE`](LICENSE).

AOSP is Apache-2.0. **libusb (LGPL-2.1-or-later) is linked statically into `adb.exe`**; the
complete source and build scripts are published so it can be relinked. See
[`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md), [`NOTICE.md`](NOTICE.md) and
[`COPYING.LGPL-2.1`](COPYING.LGPL-2.1).

## Related

- [`UPSTREAM.md`](UPSTREAM.md) — components, pins, licences, patch counts
- `ffmpeg-rt` and `scrcpy-rt`
- [rt2](https://github.com/hamed7ir/llvm-rt1) — the toolchain
