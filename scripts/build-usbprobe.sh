#!/bin/sh
# adb-rt BATCH-ADB-6 §2: build libusb + usbprobe for BOTH architectures.
# The x64 build runs on the dev box and is the GATE before anything reaches the Surface RT.
set -u
export MSYS2_ARG_CONV_EXCL='*'
export TMP="${TMP:-${TEMP:-/tmp}}" TEMP="$TMP"

# ---- configuration -------------------------------------------------------------------------
# Every absolute path lives in config.sh at the repo root, and the root is derived from THIS
# script's own location, so a clone builds wherever it is placed.
ADB_SELF=$0
ADB_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ADB_ROOT/config.sh"
rt_check_config || exit 1
LIBUSB=$ADB_ROOT_W/deps/libusb-1.0.28
B=$ADB_ROOT/build

V=$("$RT2/clang-cl.exe" --version | head -1)
case "$V" in *23.1.1-rt2*) echo "GATE OK: $V" ;; *) echo "GATE FAIL: $V"; exit 1 ;; esac

build_arch() {  # build_arch <tag> <toolchain> <machine> <libdir>
  tag="$1"; tc="$2"; mach="$3"
  SRC=$B/libusb-src-$tag; BLD=$B/libusb-$tag
  rm -rf "$SRC" "$BLD"; mkdir -p "$SRC"
  cp $ADB_ROOT/cross/libusb-CMakeLists.txt "$SRC/CMakeLists.txt"
  "$CMAKE" -G Ninja -S "$(cygpath -w "$SRC")" -B "$(cygpath -w "$BLD")" \
     -DCMAKE_MAKE_PROGRAM="$NINJA" -DCMAKE_TOOLCHAIN_FILE="$tc" \
     -DCMAKE_BUILD_TYPE=Release -DLIBUSB_DIR="$LIBUSB" > "$BLD.cfg.log" 2>&1 \
     || { echo "   $tag: CONFIGURE FAILED"; tail -5 "$BLD.cfg.log"; return 1; }
  "$CMAKE" --build "$(cygpath -w "$BLD")" > "$BLD.build.log" 2>&1 \
     || { echo "   $tag: BUILD FAILED"; grep -m5 'error' "$BLD.build.log"; return 1; }
  echo "   $tag libusb: $(stat -c%s "$BLD/usb-1.0.lib") bytes"

  # the probe, same pins as adb, statically linked
  OUT=$B/usbprobe-$tag; mkdir -p "$OUT"
  RSP="$OUT/pin.rsp"
  {
    echo "--target=$mach"
    echo "-vctoolsdir \"$VCTOOLS\""
    echo "-winsdkdir \"$WINSDK\""
    echo '-winsdkversion 10.0.19041.0'
    echo '/MT'
    echo '/DWIN32_LEAN_AND_MEAN /D_CRT_SECURE_NO_WARNINGS'
    echo "-I\"$LIBUSB/libusb\""
  } > "$RSP"
  "$RT2/clang-cl.exe" "@$(cygpath -w "$RSP")" /c "$(cygpath -w $ADB_ROOT/tools/usbprobe.c)" \
      "/Fo$(cygpath -w "$OUT/usbprobe.obj")" > "$OUT/cc.log" 2>&1 \
      || { echo "   $tag: probe COMPILE FAILED"; grep -m5 'error' "$OUT/cc.log"; return 1; }
  LRSP="$OUT/link.rsp"
  {
    echo '/SUBSYSTEM:CONSOLE'
    [ "$tag" = "arm32" ] && echo '/MACHINE:ARM' || echo '/MACHINE:X64'
    echo "/OUT:$(cygpath -w "$OUT/usbprobe.exe")"
    echo '/DEFAULTLIB:libcmt.lib /DEFAULTLIB:oldnames.lib'
    if [ "$tag" = "arm32" ]; then
      echo "/LIBPATH:\"$(cygpath -w '$VCTOOLS/lib/arm')\""
      echo "/LIBPATH:\"$(cygpath -w '$WINSDK/Lib/10.0.19041.0/ucrt/arm')\""
      echo "/LIBPATH:\"$(cygpath -w '$WINSDK/Lib/10.0.19041.0/um/arm')\""
    else
      echo "/LIBPATH:\"$(cygpath -w '$VCTOOLS/lib/x64')\""
      echo "/LIBPATH:\"$(cygpath -w '$WINSDK/Lib/10.0.19041.0/ucrt/x64')\""
      echo "/LIBPATH:\"$(cygpath -w '$WINSDK/Lib/10.0.19041.0/um/x64')\""
    fi
    cygpath -w "$OUT/usbprobe.obj"
    cygpath -w "$BLD/usb-1.0.lib"
    for l in advapi32 ole32 setupapi winmm user32 kernel32 cfgmgr32; do echo "$l.lib"; done
  } > "$LRSP"
  "$RT2/lld-link.exe" "@$(cygpath -w "$LRSP")" > "$OUT/link.log" 2>&1 \
      || { echo "   $tag: probe LINK FAILED"; grep -m8 'error' "$OUT/link.log"; return 1; }
  echo "   $tag usbprobe.exe: $(stat -c%s "$OUT/usbprobe.exe") bytes"
}

echo "=== x64 (the gate, runs here) ==="
build_arch x64 $ADB_ROOT_W/cross/x64-host-clang-cl.cmake x86_64-pc-windows-msvc
echo "=== arm32 ==="
build_arch arm32 $ADB_ROOT_W/cross/arm32-clang-cl.cmake thumbv7-unknown-windows-msvc
