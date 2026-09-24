#!/bin/sh
# adb-rt: build the two small AOSP libraries adb links: libdiagnose_usb and libcrypto_utils.
# Both are one source file each. Fetched at tag platform-tools-35.0.2 by fetch-deps.sh.
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
OUT=$ADB_ROOT/build/aosp-small
rm -rf "$OUT"; mkdir -p "$OUT"

sh $ADB_ROOT/scripts/pin-rsp.sh > "$OUT/pin.rsp"
echo "-I\"$ADB_ROOT_W/deps/libdiagnose_usb/include\"" >> "$OUT/pin.rsp"
echo "-I\"$ADB_ROOT_W/deps/libcrypto_utils/include\"" >> "$OUT/pin.rsp"
# a .c file must not get the C++-only flags
grep -vE '^/std:c\+\+20$|^/EHs-c-$' "$OUT/pin.rsp" > "$OUT/pin-c.rsp"
RSP="$(cygpath -w "$OUT/pin.rsp")"
RSPC="$(cygpath -w "$OUT/pin-c.rsp")"

OK=0; FAIL=0; N=0
cc() { # cc <rsp> <src> <objname>
  N=$((N+1))
  "$RT2/clang-cl.exe" "@$1" /c "$(cygpath -w "$2")" "/Fo$(cygpath -w "$OUT/$3.obj")" > "$OUT/$3.log" 2>&1
  if [ $? -eq 0 ] && [ -f "$OUT/$3.obj" ]; then
    OK=$((OK+1)); printf "   %-22s OK   %s bytes\n" "$3" "$(stat -c%s "$OUT/$3.obj")"
  else
    FAIL=$((FAIL+1)); printf "   %-22s FAIL %s\n" "$3" "$(grep -m1 'error' "$OUT/$3.log" | sed 's/^.*error: //' | cut -c1-70)"
  fi
}
cc "$RSP"  "$D/libdiagnose_usb/diagnose_usb.cpp" diagnose_usb
cc "$RSP"  "$D/libcrypto_utils/android_pubkey.cpp" android_pubkey   # .cpp at this tag
echo "aosp-small = $N (denominator)  built = $OK  failed = $FAIL"
