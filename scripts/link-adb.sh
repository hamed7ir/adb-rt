#!/bin/sh
# adb-rt READING T16: attempt to link adb.exe for ARM32.
# A failure here is EXPECTED and is the deliverable: the undefined set, grouped by provider.
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
B=$ADB_ROOT/build
OUT=$B/link
rm -rf "$OUT"; mkdir -p "$OUT"
w() { cygpath -w "$1"; }

RSP="$OUT/link.rsp"
: > "$RSP"
{
  echo '/SUBSYSTEM:CONSOLE'
  echo '/MACHINE:ARM'
  echo "/OUT:$(w "$OUT/adb.exe")"
  # /MT static CRT. Do NOT also pass /NODEFAULTLIB:libcmt.lib -- NODEFAULTLIB wins over
  # DEFAULTLIB, which excluded the CRT entirely and produced 20 undefined CRT symbols
  # (__security_cookie, _errno, mainCRTStartup, __tls_used).
  echo '/DEFAULTLIB:libcmt.lib'
  echo '/DEFAULTLIB:libcpmt.lib'
  echo '/DEFAULTLIB:oldnames.lib'
  # adb is a -municode program: client/main.cpp defines wmain. lld warned
  # "found both wmain and main; using latter", so name the Unicode entry point explicitly.
  echo '/ENTRY:wmainCRTStartup'
  # READING U6 -- BoringSSL's thread_win.cc hardcodes x86 name decoration in its non-_WIN64
  # branch:  /INCLUDE:__tls_used  and  /INCLUDE:_p_thread_callback_boringssl
  # ARM32 Windows is 32-bit but uses UNDECORATED names like x64/ARM64. Measured: ARM32
  # libcmt.lib defines _tls_used (1) and __tls_used (0); crypto.lib defines
  # p_thread_callback_boringssl undecorated. Aliasing keeps the patch count at 1.
  echo '/ALTERNATENAME:__tls_used=_tls_used'
  echo '/ALTERNATENAME:_p_thread_callback_boringssl=p_thread_callback_boringssl'
  # QUOTE the paths: a response-file entry splits on spaces, so an unquoted
  # /LIBPATH:D:\Program Files\... becomes two arguments and every lib goes missing.
  # Same trap as the compiler pin in pin-rsp.sh.
  echo "/LIBPATH:\"$(w '$VCTOOLS/lib/arm')\""
  echo "/LIBPATH:\"$(w '$WINSDK/Lib/10.0.19041.0/ucrt/arm')\""
  echo "/LIBPATH:\"$(w '$WINSDK/Lib/10.0.19041.0/um/arm')\""
} >> "$RSP"
for o in $(find "$B/adb-obj/obj" "$B/adb-extras/obj" "$B/shims" "$B/aosp-small" -maxdepth 1 -name '*.obj' 2>/dev/null); do w "$o" >> "$RSP"; done
for l in "$B/libbase-arm32/libbase.lib" "$B/bssl-noasm/ssl.lib" "$B/bssl-noasm/crypto.lib" \
         "$B/libusb-arm32/usb-1.0.lib" "$B/pbfull-arm32/libprotobuf.lib" "$B/pblite-arm32/libprotobuf-lite.lib"          "$B/lz4-arm32/lz4.lib" "$B/brotli-arm32/brotli.lib" "$B/zstd-arm32/zstd.lib"; do
  [ -f "$l" ] && w "$l" >> "$RSP"
done
for s in ws2_32 gdi32 userenv iphlpapi advapi32 ole32 setupapi winmm shlwapi crypt32 shell32 user32 kernel32; do
  echo "$s.lib" >> "$RSP"
done

echo "objects+libs in response file = $(grep -c . "$RSP")"
"$RT2/lld-link.exe" "@$(w "$RSP")" > "$OUT/link.log" 2>&1
rc=$?
echo "lld-link exit = $rc"
if [ -f "$OUT/adb.exe" ]; then
  echo "adb.exe = $(stat -c%s "$OUT/adb.exe") bytes"
else
  echo "adb.exe NOT produced"
fi
echo "undefined-symbol errors = $(grep -c 'undefined symbol' "$OUT/link.log")"
