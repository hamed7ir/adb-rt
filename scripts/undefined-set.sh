#!/bin/sh
# adb-rt §1.1 (BATCH-ADB-2B) -- READING T1/T2.
#
# THE METHOD: Android.bp's static_libs is what the daemon PLUS host PLUS everything needs.
# It is NOT what OUR link needs. Ask the objects instead.
#
# S7.2: a failed reader is not evidence. llvm-nm self-tests on a known-good object and this
# script EXITS NON-ZERO if the reader cannot read -- it never reports an empty set as a finding.
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
OBJ=$ADB_ROOT/build/adb-obj/obj
OUT=$ADB_ROOT/build/undef
rm -rf "$OUT"; mkdir -p "$OUT"
w() { cygpath -w "$1"; }

N=$(find "$OBJ" -name '*.obj' | wc -l)
echo "objects = $N"
[ "$N" -gt 0 ] || { echo "!!! ZERO OBJECTS - nothing to ask. Not a finding."; exit 1; }

# ---- READER SELF-TEST (S7.2) ----
P=$(find "$OBJ" -name '*.obj' | head -1)
if ! "$NM" "$(w "$P")" > "$OUT/selftest.txt" 2>&1; then
  echo "!!! READER SELF-TEST FAILED - llvm-nm cannot open $P"; head -3 "$OUT/selftest.txt"; exit 2
fi
SYMS=$(wc -l < "$OUT/selftest.txt")
if [ "$SYMS" -lt 10 ]; then
  echo "!!! READER SELF-TEST SUSPECT - only $SYMS lines from a real object. Refusing to report."; exit 2
fi
echo "reader self-test OK ($SYMS symbol lines from $(basename "$P"))"

# ---- collect ----
: > "$OUT/undef.raw"; : > "$OUT/def.raw"
find "$OBJ" -name '*.obj' | while read -r o; do
  "$NM" --undefined-only "$(w "$o")" 2>/dev/null | awk '{print $NF}' >> "$OUT/undef.raw"
  "$NM" --defined-only   "$(w "$o")" 2>/dev/null | awk '{print $NF}' >> "$OUT/def.raw"
done
sort -u "$OUT/undef.raw" > "$OUT/undef.all"
sort -u "$OUT/def.raw"   > "$OUT/def.all"

# internal = satisfied by our own 31 objects; external = the real requirement
comm -23 "$OUT/undef.all" "$OUT/def.all" > "$OUT/undef.external"

echo
echo "READING T1"
echo "  undefined symbols, deduplicated      = $(wc -l < "$OUT/undef.all")"
echo "  defined by our own objects           = $(wc -l < "$OUT/def.all")"
echo "  EXTERNAL (not satisfied internally)  = $(wc -l < "$OUT/undef.external")"
