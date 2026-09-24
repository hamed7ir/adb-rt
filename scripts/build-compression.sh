#!/bin/sh
# adb-rt: build lz4, brotli and zstd for ARM32. All three are plain portable C.
# compression_utils.h includes <brotli/decode.h>, <lz4frame.h> AND <zstd.h> unguarded, so
# client/file_sync_client.cpp needs all three; client/incremental_server.cpp needs <lz4.h>.
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
D=$ADB_ROOT/deps
B=$ADB_ROOT/build

# C sources: strip the C++-only flags from the shared pin
mkpin() { sh $ADB_ROOT/scripts/pin-rsp.sh | grep -vE '^/std:c\+\+20$|^/EHs-c-$|^/FI' > "$1"; }

lib() {  # lib <name> <extra-include> <source...>
  name="$1"; inc="$2"; shift 2
  OUT="$B/$name-arm32"; rm -rf "$OUT"; mkdir -p "$OUT/obj"
  mkpin "$OUT/pin.rsp"
  # cygpath -w: clang-cl is native, an MSYS /d/... -I is silently useless
  [ -n "$inc" ] && echo "-I\"$(cygpath -w "$inc")\"" >> "$OUT/pin.rsp"
  RSP="$(cygpath -w "$OUT/pin.rsp")"
  ok=0; fail=0; n=0
  for f in "$@"; do
    [ -f "$f" ] || continue
    n=$((n+1)); b=$(basename "$f" .c)
    "$RT2/clang-cl.exe" "@$RSP" /c "$(cygpath -w "$f")" "/Fo$(cygpath -w "$OUT/obj/$b.obj")" > "$OUT/obj/$b.log" 2>&1
    if [ $? -eq 0 ] && [ -f "$OUT/obj/$b.obj" ]; then ok=$((ok+1)); else
      fail=$((fail+1)); printf "      %-22s %s\n" "$b" "$(grep -m1 'error' "$OUT/obj/$b.log" | sed 's/^.*error: //' | cut -c1-70)"
    fi
  done
  "$RT2/llvm-lib.exe" "/OUT:$(cygpath -w "$OUT/$name.lib")" $(find "$OUT/obj" -name '*.obj' -exec cygpath -w {} \;) > "$OUT/lib.log" 2>&1
  printf "   %-10s sources=%s built=%s failed=%s  %s.lib = %s bytes\n" "$name" "$n" "$ok" "$fail" "$name" "$(stat -c%s "$OUT/$name.lib" 2>/dev/null || echo 0)"
}

echo "=== lz4 ==="
lib lz4 "" "$D/lz4-1.9.4/lib/lz4.c" "$D/lz4-1.9.4/lib/lz4hc.c" "$D/lz4-1.9.4/lib/lz4frame.c" "$D/lz4-1.9.4/lib/xxhash.c"
echo "=== brotli ==="
lib brotli "$D/brotli-1.1.0/c/include" $(find "$D/brotli-1.1.0/c/common" "$D/brotli-1.1.0/c/dec" "$D/brotli-1.1.0/c/enc" -name '*.c' 2>/dev/null)
echo "=== zstd ==="
lib zstd "$D/zstd-1.5.6/lib" $(find "$D/zstd-1.5.6/lib/common" "$D/zstd-1.5.6/lib/compress" "$D/zstd-1.5.6/lib/decompress" -name '*.c' 2>/dev/null)
