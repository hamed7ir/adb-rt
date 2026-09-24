#!/bin/sh
# adb-rt: build AOSP libbase for ARM32 Windows with rt2.
#
# libbase is a static_lib adb links but which was never built -- T2 measured 34 undefined
# android::base symbols. The .bp dependency list said "libbase" and nothing about it being
# unbuilt, which is exactly why the undefined set is ground truth and the list is not.
#
# Source list from libbase_defaults (Android.bp): the common srcs, MINUS cmsg.cpp
# (exclude_srcs on windows), PLUS errors_windows.cpp and utf8.cpp.
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
B=$ADB_ROOT/deps/libbase
OUT=$ADB_ROOT/build/libbase-arm32
rm -rf "$OUT"; mkdir -p "$OUT/obj" "$OUT/log"

V=$("$RT2/clang-cl.exe" --version | head -1)
case "$V" in *23.1.1-rt2*) echo "GATE OK: $V" ;; *) echo "GATE FAIL"; exit 1 ;; esac

# ! libbase must NOT inherit adb's flags. adb_defaults sets -DUNICODE/-D_UNICODE for its own
# modules; libbase_cflags_defaults sets NEITHER -- only -D_POSIX_THREAD_SAFE_FUNCTIONS on
# windows. With UNICODE defined, file.cpp:505's GetModuleFileName(NULL, char[], ...) resolves
# to GetModuleFileNameW and fails with "no matching function" (it wants LPWSTR). Upstream is
# correct; inheriting the wrong module's flags was the bug.
sh $ADB_ROOT/scripts/pin-rsp.sh | sed 's,/DUNICODE=1 ,,; s,/D_UNICODE=1 ,,' > "$OUT/pin.rsp"
echo "/D_POSIX_THREAD_SAFE_FUNCTIONS" >> "$OUT/pin.rsp"
echo "-I\"$ADB_ROOT_W/deps/libbase\"" >> "$OUT/pin.rsp"
RSP="$(cygpath -w "$OUT/pin.rsp")"

SRCS="abi_compatibility.cpp chrono_utils.cpp file.cpp hex.cpp logging.cpp mapped_file.cpp parsebool.cpp parsenetaddress.cpp posix_strerror_r.cpp process.cpp properties.cpp result.cpp stringprintf.cpp strings.cpp threads.cpp test_utils.cpp errors_windows.cpp utf8.cpp"

OK=0; FAIL=0; N=0
: > "$OUT/failed.txt"
for f in $SRCS; do
  N=$((N+1))
  [ -f "$B/$f" ] || { printf '%-28s NO SUCH SOURCE\n' "$f" >> "$OUT/failed.txt"; FAIL=$((FAIL+1)); continue; }
  "$RT2/clang-cl.exe" "@$RSP" /c "$(cygpath -w "$B/$f")" "/Fo$(cygpath -w "$OUT/obj/$f.obj")" > "$OUT/log/$f.log" 2>&1
  if [ $? -eq 0 ] && [ -f "$OUT/obj/$f.obj" ]; then OK=$((OK+1)); else
    FAIL=$((FAIL+1))
    printf '%-28s %s\n' "$f" "$(grep -m1 -E 'error:' "$OUT/log/$f.log" | sed 's/^.*error: //' | cut -c1-90)" >> "$OUT/failed.txt"
  fi
done
echo "libbase sources = $N (denominator)   built = $OK   failed = $FAIL"
[ -s "$OUT/failed.txt" ] && { echo "--- failures ---"; cat "$OUT/failed.txt"; }
if [ "$OK" -gt 0 ]; then
  "$RT2/llvm-lib.exe" "/OUT:$(cygpath -w "$OUT/libbase.lib")" $(find "$OUT/obj" -name '*.obj' -exec cygpath -w {} \; ) > "$OUT/lib.log" 2>&1
  echo "libbase.lib = $(stat -c%s "$OUT/libbase.lib" 2>/dev/null || echo 0) bytes"
fi
