#!/bin/sh
# BATCH-ADB-7 section 3: an x64 twin of adb's OUTPUT PATH, so the "writes nothing to a pipe"
# defect can be cornered on the dev box instead of on the Surface.
#
# The only architecture-specific line in scripts/pin-rsp.sh is the target triple; everything
# else -- toolset, SDK, /MT, /EHs-c-, /std:c++20, every -I, the forced includes -- is portable.
# So the twin is the same pin with one line swapped, which is what makes it a twin rather than
# a rewrite.
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

ROOT=$ADB_ROOT
OUT=$ROOT/build/x64-twin

V=$("$RT2/clang-cl.exe" --version | head -1)
case "$V" in *23.1.1-rt2*) echo "GATE OK: $V" ;; *) echo "GATE FAIL: $V"; exit 1 ;; esac

rm -rf "$OUT"; mkdir -p "$OUT/obj" "$OUT/log"

# the pin, with exactly one line changed
sh "$ROOT/scripts/pin-rsp.sh" \
  | sed 's,^--target=thumbv7-unknown-windows-msvc$,--target=x86_64-pc-windows-msvc,' \
  > "$OUT/pin.rsp"
grep -q '^--target=x86_64-pc-windows-msvc$' "$OUT/pin.rsp" \
  || { echo "GATE FAIL: target line not rewritten -- the twin would be ARM32"; exit 1; }
echo "pin: $(grep '^--target' "$OUT/pin.rsp")"
RSP="$(cygpath -w "$OUT/pin.rsp")"

# ---- libbase for x64 ------------------------------------------------------------------
# Same source list and the same UNICODE removal as scripts/build-libbase.sh: libbase must NOT
# inherit adb's -DUNICODE, or file.cpp:505's GetModuleFileName resolves to the W variant.
LB=$ROOT/deps/libbase
sed 's,/DUNICODE=1 ,,; s,/D_UNICODE=1 ,,' "$OUT/pin.rsp" > "$OUT/pin-libbase.rsp"
echo '/D_POSIX_THREAD_SAFE_FUNCTIONS' >> "$OUT/pin-libbase.rsp"
echo "-I\"$ADB_ROOT_W/deps/libbase\"" >> "$OUT/pin-libbase.rsp"
LBRSP="$(cygpath -w "$OUT/pin-libbase.rsp")"

LBSRCS="abi_compatibility.cpp chrono_utils.cpp file.cpp hex.cpp logging.cpp mapped_file.cpp parsebool.cpp parsenetaddress.cpp posix_strerror_r.cpp process.cpp properties.cpp result.cpp stringprintf.cpp strings.cpp threads.cpp test_utils.cpp errors_windows.cpp utf8.cpp"
LBN=0; LBOK=0
for f in $LBSRCS; do
  LBN=$((LBN+1))
  if "$RT2/clang-cl.exe" "@$LBRSP" /c "$(cygpath -w "$LB/$f")" \
       "/Fo$(cygpath -w "$OUT/obj/lb_$f.obj")" > "$OUT/log/lb_$f.log" 2>&1; then
    LBOK=$((LBOK+1))
  else
    echo "  libbase FAILED: $f"; grep -m3 -i error "$OUT/log/lb_$f.log"
  fi
done
# ⚠ result.cpp is EXPECTED to fail: it includes android-base/format.h, which needs fmt/chrono.h,
# and libfmt is not vendored in this tree. The SHIPPING ARM32 libbase has exactly the same
# failure (build/libbase-arm32/failed.txt: "result.cpp  'fmt/chrono.h' file not found", 17
# objects) and adb.exe was linked without it. The twin must match the shipping build, so 17/18
# with result.cpp as the ONLY failure is the pass condition -- and it is asserted, not assumed.
echo "libbase x64: $LBOK / $LBN compiled"
if [ "$LBOK" -ne 17 ]; then echo "GATE FAIL: expected 17 libbase objects, got $LBOK"; exit 1; fi
if [ -f "$OUT/obj/lb_result.cpp.obj" ]; then echo "GATE FAIL: result.cpp built here but not on ARM32 -- not a twin"; exit 1; fi
echo "libbase x64: 17/18, result.cpp absent -- matches the ARM32 build exactly"

# ---- the link-debt shims, same set the ARM32 build uses --------------------------------
# cross/aosp-stubs/compat/ -- the POSIX/liblog surface AOSP assumes and MSVC does not provide.
# Only the FIVE that sysdeps_win32.cpp actually references, established by linking without any
# of them and reading the undefined set: nftw (ftw), dirname/basename (libgen),
# __android_log_* (liblog-stub), clock_gettime (clock), readdir/_wopendir (dirent).
# install-opts-stub and mdns-stub are deliberately OUT: they pull
# com::android::fastdeploy::APKMetaData and AdbCloser::Close, i.e. adb's protobuf and fd
# machinery, into a probe about four printf wrappers.
for b in ftw.cpp libgen.cpp liblog-stub.cpp clock.cpp dirent.cpp; do
  f=$ROOT/cross/aosp-stubs/compat/$b
  "$RT2/clang-cl.exe" "@$RSP" /c "$(cygpath -w "$f")" \
      "/Fo$(cygpath -w "$OUT/obj/shim_$b.obj")" > "$OUT/log/shim_$b.log" 2>&1 \
    || { echo "  shim FAILED: $b"; grep -m5 -i error "$OUT/log/shim_$b.log"; exit 1; }
done
echo "shims: $(ls "$OUT"/obj/shim_*.obj | wc -l) compiled"

# ---- adb's real sysdeps_win32.cpp, and the probe --------------------------------------
# sysdeps/win32/errno.cpp carries adb_strerror, which sysdeps_win32.cpp references. adb_trace.cpp
# was tried and REJECTED: it drags in adb_version(), AdbCloser and the fastdeploy protobuf, i.e.
# adb's whole world, for one int. adb_trace_mask is defined in the probe instead -- it is a
# variable, not logic under test.
for f in sysdeps_win32.cpp sysdeps/win32/errno.cpp; do
  flat=$(echo "$f" | tr '/' '_')
  "$RT2/clang-cl.exe" "@$RSP" /c "$(cygpath -w "$ROOT/deps/adb-35.0.2/$f")" \
      "/Fo$(cygpath -w "$OUT/obj/$flat.obj")" > "$OUT/log/$flat.log" 2>&1 \
    || { echo "  FAILED: $f"; grep -m8 -i error "$OUT/log/$flat.log"; exit 1; }
  echo "compiled $f"
done

"$RT2/clang-cl.exe" "@$RSP" /c "$(cygpath -w "$ROOT/tools/stdout-probe.cpp")" \
    "/Fo$(cygpath -w "$OUT/obj/stdout-probe.obj")" > "$OUT/log/probe.log" 2>&1 \
  || { echo "  FAILED: stdout-probe.cpp"; grep -m8 -i error "$OUT/log/probe.log"; exit 1; }
echo "compiled stdout-probe.cpp"

VC=$VCTOOLS
SDK=$WINSDK
SDKVER=$WINSDKVER
LRSP="$OUT/link.rsp"
{
  echo '/SUBSYSTEM:CONSOLE'
  echo '/MACHINE:X64'
  # ⚠ THE SHIPPING adb LINKS THIS WAY AND SO MUST THE TWIN.
  # sysdeps_win32.cpp:2911 provides `extern "C" int wmain(int, wchar_t**)`; :2932 LOG(FATAL)s
  # with "_wenviron is not set, did you link with -municode?" if the wide entry point was not
  # used. Without it the twin dies in adb's own initialisation before reaching a single printf,
  # which looks exactly like the zero-byte defect and is not it. Read out of build/link/link.rsp,
  # not assumed.
  echo '/ENTRY:wmainCRTStartup'
  echo "/OUT:$(cygpath -w "$OUT/stdout-probe.exe")"
  echo '/DEFAULTLIB:libcmt.lib /DEFAULTLIB:libcpmt.lib /DEFAULTLIB:oldnames.lib'
  echo "/LIBPATH:\"$(cygpath -w "$VC/lib/x64")\""
  echo "/LIBPATH:\"$(cygpath -w "$SDK/Lib/$SDKVER/ucrt/x64")\""
  echo "/LIBPATH:\"$(cygpath -w "$SDK/Lib/$SDKVER/um/x64")\""
  for o in "$OUT"/obj/*.obj; do cygpath -w "$o"; done
  for l in advapi32 shell32 user32 ole32 shlwapi ws2_32 userenv kernel32; do echo "$l.lib"; done
} > "$LRSP"

"$RT2/lld-link.exe" "@$(cygpath -w "$LRSP")" > "$OUT/link.log" 2>&1 \
  || { echo "LINK FAILED"; grep -m25 -iE "error|unresolved" "$OUT/link.log"; exit 1; }
echo "stdout-probe.exe (x64): $(stat -c%s "$OUT/stdout-probe.exe") bytes"
