# adb-rt WinUSB driver package

Binds the phone's ADB interface to Windows' in-box **WinUSB** driver so libusb — and therefore
`adb.exe` — can claim it on 32-bit ARM Windows (Windows RT 8.1).

> ## ⚠ ON WINDOWS RT THIS INF MUST BE SIGNED. There is no unsigned path.
>
> Measured on the Surface RT, on both `&PID_201C` and `&PID_201D&MI_01`, **with test-signing
> already ON**:
>
> ```
> The third-party INF does not contain digital signature information.
> ```
>
> RT offers **no "Install this driver software anyway" option** — that prompt exists on desktop
> Windows and is not offered here. The `(WinUSB, ARM32)` device description in that error proves
> the `NTarm` section was selected correctly: the INF is fine, the *package* was unsigned.
>
> **It installs once three things are true together** — test-signing ON, the INF signed with a
> SHA-256 catalog, and the signing certificate imported into **Trusted Root** *and* **Trusted
> Publishers** on that device. Test-signing does not switch signature checking off; it permits a
> chain to a root you installed instead of requiring one to Microsoft, so with it off a
> self-signed package is refused too. Full procedure, including the PowerShell route that
> worked when `Inf2Cat` (WDK-only) and `makecat` (absent) were not available:
> [`sign/README.md`](sign/README.md).

## Two paths to a bound ADB interface

Which one you are on depends on the handset, not on anything here.

**Path A — nothing to install.** A phone whose ADB interface carries a **WinUSB descriptor**
is bound by Windows itself. On RT a *composite* child still needs one registry value before
libusb can reach it: run `tools/adb-usb-check.cmd`, then `tools/adb-usb-bind.cmd` as
administrator, then replug. The Volla Phone Quintus and the Google Pixel 9 Pro XL are this kind.

**Path B — a signed INF.** A phone with no WinUSB descriptor has no driver on its ADB
interface. It needs an INF generated with its own hardware IDs by `make-inf.sh`, signed as
above. The BlackBerry Priv is this kind.

```
adb-rt-winusb.inf   the driver package (generated; do not hand-edit)
make-inf.sh         the generator
sign/README.md      signing — MANDATORY on RT, read it before installing anything
```

## Install steps are in `dist/README.txt`

The numbered procedure for the device — scan, install, verify the **Service** field, run the
USB test — lives in `dist\README.txt` alongside the shims it tells you to run. Follow that.

## What it binds

This phone has **three ADB-bearing USB modes, each a different hardware ID**. All three are
covered. Measured on the dev box against a MediaTek-based handset, VID `0E8D`:

| USB mode | ADB hardware ID | layout | parent |
|---|---|---|---|
| File transfer | `USB\VID_0E8D&PID_201D&MI_01` | composite | `usbccgp` |
| PTP | `USB\VID_0E8D&PID_200C&MI_01` | composite | `usbccgp` |
| No data transfer | `USB\VID_0E8D&PID_201C` | single interface | — |

**No `usbccgp` / `Composite.Dev` sections, deliberately.** The composite *parents* bind
themselves to the in-box `usbccgp` driver through the generic `USB\COMPOSITE` compatible ID in
`usb.inf`, with no vendor INF involved — which is why file browsing already worked on the RT
with nothing installed. The split into `&MI_00` / `&MI_01` happens on any Windows. Only the
`&MI_01` **child** needs binding.

The two forms use **different description strings**, so Device Manager's name tells you which
model line matched:

| name shown | matched |
|---|---|
| `Android ADB Interface (WinUSB, ARM32)` | the bare `PID_201C` |
| `Android Composite ADB Interface (WinUSB, ARM32)` | a `&MI_01` child |

## Regenerating

**Do not hand-edit the `.inf`.** Every failure mode it has is silent on the device — a `NTarm`
decoration without a matching section installs nothing and reports no error; a model line
dropped from one architecture's section installs nothing on that architecture and reports no
error; a stray co-installer reference fails the install. The checks that catch these only run
in the generator.

```bash
cd <repo>/driver
./make-inf.sh 'USB\VID_0E8D&PID_201C' 'USB\VID_0E8D&PID_201D&MI_01' 'USB\VID_0E8D&PID_200C&MI_01'
```

It refuses placeholder or malformed IDs, writes CRLF/ASCII with no BOM, and **asserts** on:
`NTarm` directives = 2, CoInstallers = 0, `usbccgp` sections = 0, and **every ID present in every decorated section** (9 model lines for 3 IDs). That last check is negative-tested: deleting one line from one section makes it exit non-zero and name the missing ID. It exits non-zero rather than
emitting a file that would fail quietly on the device.

Pass different IDs to target a different USB mode — each Android USB mode is a different PID.
