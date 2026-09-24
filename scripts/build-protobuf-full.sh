#!/bin/sh
# adb-rt §5: FULL protobuf C++ runtime for ARM32 Windows with rt2.
#
# REQUIRED, not optional. Proven twice, by two independent methods:
#   1. proto/Android.bp declares libadb_host_protos (adb_host.proto) as type: "full",
#      and adb.cpp / transport.cpp / client/commandline.cpp all include adb_host.pb.h.
#   2. At the LINK: ?PrintToString@TextFormat@protobuf@google@@ is undefined in our objects
#      and is NOT provided by libprotobuf-lite. TextFormat is full-runtime only.
#
# protobuf_WITH_ZLIB=OFF: full protobuf uses zlib for Gzip{Input,Output}Stream, and there is
# no ARM32 zlib here. adb does not use the gzip streams. (The lite build had ZLIB=ON only
# because lite never references zlib, so the setting was inert.)
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

SRC=$ADB_ROOT_W/deps/protobuf-3.21.12
BLD=$ADB_ROOT/build/pbfull-arm32

V=$("$RT2/clang-cl.exe" --version | head -1)
case "$V" in *23.1.1-rt2*) echo "GATE OK: $V" ;; *) echo "GATE FAIL: $V"; exit 1 ;; esac

rm -rf "$BLD"
"$CMAKE" -G Ninja -S "$SRC" -B "$(cygpath -w "$BLD")" -DCMAKE_MAKE_PROGRAM="$NINJA" -DCMAKE_TOOLCHAIN_FILE=$ADB_ROOT_W/cross/arm32-clang-cl.cmake -DCMAKE_BUILD_TYPE=Release -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_PROTOC_BINARIES=OFF -Dprotobuf_WITH_ZLIB=OFF -Dprotobuf_BUILD_SHARED_LIBS=OFF
"$CMAKE" --build "$(cygpath -w "$BLD")" --target libprotobuf -- -j12
echo "--- build exit=$? ---"
