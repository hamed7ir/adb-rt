#!/bin/sh
# adb-rt: compile every compat/stub .cpp in cross/aosp-stubs/compat for ARM32.
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
C=$ADB_ROOT/cross/aosp-stubs/compat
OUT=$ADB_ROOT/build/shims
rm -rf "$OUT"; mkdir -p "$OUT"
sh $ADB_ROOT/scripts/pin-rsp.sh > "$OUT/pin.rsp"
RSP="$(cygpath -w "$OUT/pin.rsp")"
OK=0; FAIL=0; N=0
for f in "$C"/*.cpp; do
  N=$((N+1)); b=$(basename "$f" .cpp)
  "$RT2/clang-cl.exe" "@$RSP" /c "$(cygpath -w "$f")" "/Fo$(cygpath -w "$OUT/$b.obj")" > "$OUT/$b.log" 2>&1
  if [ $? -eq 0 ] && [ -f "$OUT/$b.obj" ]; then
    OK=$((OK+1)); printf "   %-16s OK   %s bytes\n" "$b" "$(stat -c%s "$OUT/$b.obj")"
  else
    FAIL=$((FAIL+1)); printf "   %-16s FAIL %s\n" "$b" "$(grep -m1 'error' "$OUT/$b.log" | cut -c1-80)"
  fi
done
echo "shims = $N (denominator)  built = $OK  failed = $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
