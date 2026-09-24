#!/bin/sh
# adb-rt READING T2: map each EXTERNAL undefined symbol to a providing library.
# Any library that provides NOTHING here is NOT REQUIRED and must be struck explicitly.
set -u
# ---- configuration -------------------------------------------------------------------------
# Every absolute path lives in config.sh at the repo root, and the root is derived from THIS
# script's own location, so a clone builds wherever it is placed.
ADB_SELF=$0
ADB_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ADB_ROOT/config.sh"
rt_check_config || exit 1
export MSYS2_ARG_CONV_EXCL='*'
NM="$RT2/llvm-nm.exe"
OUT=$ADB_ROOT/build/undef
w() { cygpath -w "$1"; }
[ -s "$OUT/undef.external" ] || { echo "!!! no external set - run undefined-set.sh first"; exit 1; }

index() {   # index <tag> <lib-or-dir> ...
  tag="$1"; shift
  : > "$OUT/prov.$tag"
  for x in "$@"; do
    if [ -d "$x" ]; then set -- "$x"/*.lib; else set -- "$x"; fi
    for l in "$@"; do
      [ -f "$l" ] || continue
      "$NM" --defined-only "$(w "$l")" 2>/dev/null | awk '{print $NF}' >> "$OUT/prov.$tag"
    done
  done
  sort -u "$OUT/prov.$tag" -o "$OUT/prov.$tag"
  n=$(wc -l < "$OUT/prov.$tag")
  # READER SELF-TEST per index: an unreadable library yields 0 and would look like "provides nothing"
  if [ "$n" -eq 0 ]; then
    echo "!!! READER SELF-TEST FAILED for index '$tag' - 0 symbols. Refusing to call it 'provides nothing'."
    exit 2
  fi
  echo "   index $tag: $n defined symbols"
}

echo "building provider indexes (each self-tests for non-zero)"
index bssl      $ADB_ROOT/build/bssl-noasm/crypto.lib $ADB_ROOT/build/bssl-noasm/ssl.lib
index libusb    $ADB_ROOT/build/libusb-arm32/usb-1.0.lib
index pblite    $ADB_ROOT/build/pblite-arm32/libprotobuf-lite.lib
index msvc      "$VCTOOLS/lib/arm"
index ucrt      "$WINSDK/Lib/10.0.19041.0/ucrt/arm"
index winsdk    "$WINSDK/Lib/10.0.19041.0/um/arm"

echo
echo "READING T2 - external undefined symbols by provider"
REM="$OUT/undef.external"
cp "$REM" "$OUT/rem.work"
for tag in bssl libusb pblite msvc ucrt winsdk; do
  comm -12 "$OUT/rem.work" "$OUT/prov.$tag" > "$OUT/hit.$tag"
  comm -23 "$OUT/rem.work" "$OUT/prov.$tag" > "$OUT/rem.next"
  mv "$OUT/rem.next" "$OUT/rem.work"
  printf "   %-8s provides %4s\n" "$tag" "$(wc -l < "$OUT/hit.$tag")"
done
cp "$OUT/rem.work" "$OUT/unprovided"
echo
echo "   UNPROVIDED by anything we have = $(wc -l < "$OUT/unprovided")"
