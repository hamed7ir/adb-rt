#!/bin/sh
# adb-rt: rebuild every CMake-built ARM32 dependency with the STATIC CRT (/MT).
# Required after the toolchain gained CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded -- CMake's
# default is /MD, which both breaks the link (/failifmismatch) and would add UCRT DLL imports.
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
TC=$ADB_ROOT_W/cross/arm32-clang-cl.cmake

build() {  # build <builddir> <srcdir> <target> [extra cmake args...]
  bd="$1"; sd="$2"; tgt="$3"; shift 3
  echo "=== $bd ==="
  rm -rf "$bd"
  "$CMAKE" -G Ninja -S "$sd" -B "$(cygpath -w "$bd")" -DCMAKE_MAKE_PROGRAM="$NINJA" \
      -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_BUILD_TYPE=Release "$@" > "$bd.cfg.log" 2>&1 \
      || { echo "   CONFIGURE FAILED"; tail -5 "$bd.cfg.log"; return 1; }
  if [ -n "$tgt" ]; then
    "$CMAKE" --build "$(cygpath -w "$bd")" --target "$tgt" -- -j12 > "$bd.build.log" 2>&1
  else
    "$CMAKE" --build "$(cygpath -w "$bd")" -- -j12 > "$bd.build.log" 2>&1
  fi
  echo "   build exit=$?"
}

B=$ADB_ROOT/build
build "$B/bssl-noasm"   "$ADB_ROOT_W/deps/boringssl-pinned"    ""            -DOPENSSL_NO_ASM=1
build "$B/pblite-arm32" "$ADB_ROOT_W/deps/protobuf-3.21.12"    libprotobuf-lite -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_PROTOC_BINARIES=OFF -Dprotobuf_WITH_ZLIB=OFF -Dprotobuf_BUILD_SHARED_LIBS=OFF
build "$B/pbfull-arm32" "$ADB_ROOT_W/deps/protobuf-3.21.12"    libprotobuf      -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_PROTOC_BINARIES=OFF -Dprotobuf_WITH_ZLIB=OFF -Dprotobuf_BUILD_SHARED_LIBS=OFF
