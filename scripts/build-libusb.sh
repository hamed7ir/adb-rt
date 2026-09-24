#!/bin/sh
# adb-rt: build libusb 1.0.28 static for ARM32 Windows with rt2.
# 1.0.28, NOT 1.0.27: adb 35.0.2 client/usb_libusb.cpp calls the SuperSpeed+ BOS
# descriptor API (libusb_get_ssplus_usb_device_capability_descriptor et al).
# Measured: 1.0.27 has ZERO occurrences of "ssplus" tree-wide; 1.0.28 declares all
# five symbols adb needs AND implements the parser (descriptor.c:1038).
# A version bump, not a backported fork patch.
# libusb ships no CMakeLists; cross/libusb-CMakeLists.txt compiles the ClCompile list from
# libusb's own msvc/libusb_static.vcxproj PLUS os/windows_hotplug.c, which patch 0002 adds.
# libusb carries that one patch; nothing else in its tree is modified.
set -eu
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
SRCDIR=$ADB_ROOT/build/libusb-src
BLD=$ADB_ROOT/build/libusb-arm32

# GATE - rt2 or stop
V=$("$RT2/clang-cl.exe" --version | head -1)
case "$V" in *23.1.1-rt2*) echo "GATE OK: $V" ;; *) echo "GATE FAIL: $V"; exit 1 ;; esac

rm -rf "$SRCDIR" "$BLD"; mkdir -p "$SRCDIR"
cp $ADB_ROOT/cross/libusb-CMakeLists.txt "$SRCDIR/CMakeLists.txt"

"$CMAKE" -G Ninja -S "$(cygpath -w "$SRCDIR")" -B "$(cygpath -w "$BLD")" -DCMAKE_MAKE_PROGRAM="$NINJA" -DCMAKE_TOOLCHAIN_FILE=$ADB_ROOT_W/cross/arm32-clang-cl.cmake -DCMAKE_BUILD_TYPE=Release -DLIBUSB_DIR="$LIBUSB"
echo "--- configure exit=$? ---"
"$CMAKE" --build "$(cygpath -w "$BLD")" -- -j12
echo "--- build exit=$? ---"
