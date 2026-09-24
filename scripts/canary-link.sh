#!/bin/sh
# adb-rt READING U0: the canary link. usage: canary-link.sh <lib> [<lib> ...]
# Exits non-zero on ANY model mismatch. Run it after building each dependency.
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
OUT=$ADB_ROOT/build/canary
mkdir -p "$OUT"
w() { cygpath -w "$1"; }

sh $ADB_ROOT/scripts/pin-rsp.sh > "$OUT/pin.rsp"
"$RT2/clang-cl.exe" "@$(w "$OUT/pin.rsp")" /c "$(w $ADB_ROOT/cross/canary/canary.cpp)" "/Fo$(w "$OUT/canary.obj")" > "$OUT/cc.log" 2>&1 \
  || { echo "CANARY COMPILE FAILED"; head -5 "$OUT/cc.log"; exit 2; }

RSP="$OUT/link.rsp"
{
  echo '/SUBSYSTEM:CONSOLE'
  echo '/MACHINE:ARM'
  echo "/OUT:$(w "$OUT/canary.exe")"
  echo '/DEFAULTLIB:libcmt.lib'
  echo '/DEFAULTLIB:libcpmt.lib'
  echo '/DEFAULTLIB:oldnames.lib'
  echo "/LIBPATH:\"$(w '$VCTOOLS/lib/arm')\""
  echo "/LIBPATH:\"$(w '$WINSDK/Lib/10.0.19041.0/ucrt/arm')\""
  echo "/LIBPATH:\"$(w '$WINSDK/Lib/10.0.19041.0/um/arm')\""
  w "$OUT/canary.obj"
} > "$RSP"
for l in "$@"; do
  [ -f "$l" ] || { echo "   !!! canary: '$l' does not exist (empty output is not absence)"; exit 3; }
  w "$l" >> "$RSP"
done
for s in kernel32 user32 advapi32 ws2_32; do echo "$s.lib" >> "$RSP"; done

"$RT2/lld-link.exe" "@$(w "$RSP")" > "$OUT/link.log" 2>&1
rc=$?
MM=$(grep -c 'failifmismatch' "$OUT/link.log")
if [ "$MM" -gt 0 ]; then
  echo "   CANARY: ★ MODEL MISMATCH (S6.2 - STOP and fix before building more)"
  grep -A2 'failifmismatch' "$OUT/link.log" | head -8 | sed 's/^/      /'
  exit 1
fi
# undefined symbols from a library the canary does not USE are normal and not a model problem
UND=$(grep -c 'undefined symbol' "$OUT/link.log")
if [ "$rc" -eq 0 ]; then
  echo "   CANARY OK  (exit 0, canary.exe = $(stat -c%s "$OUT/canary.exe" 2>/dev/null) bytes)  libs: $#"
else
  echo "   CANARY: no model mismatch; link exit=$rc, undefined=$UND (unused-lib symbols are expected)"
  grep -m3 'error' "$OUT/link.log" | sed 's/^/      /'
fi
exit 0
