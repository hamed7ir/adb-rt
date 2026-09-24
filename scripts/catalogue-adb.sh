#!/bin/sh
# adb-rt §4 / READING D4 -- THE BLOCKER CATALOGUE.
#
# Compiles EVERY source in adb's four Soong source lists INDEPENDENTLY (-fsyntax-only) and
# KEEPS GOING. The point is the inventory, not the first error.
#
# -Werror is deliberately NOT used. adb_defaults sets it, but a warning is not a port blocker
# and -Werror would bury the real ones.
#
# ! All compiler pins live in a RESPONSE FILE with every path QUOTED. Passing them through an
#   unquoted shell variable splits "D:/Program Files/..." on the space, silently producing a
#   compiler with NO SYSROOT -- which then reports `'errno.h' file not found` for all 49 files.
#   That looks exactly like a catastrophic port blocker and is nothing of the kind. Hence the
#   SYSROOT SELF-TEST below, which must pass before any result is believed.
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

S=$ADB_ROOT/deps/adb-35.0.2
OUT=$ADB_ROOT/build/catalogue
RSP="$(cygpath -w "$OUT/pin.rsp")"
mkdir -p "$OUT"
# the pin lives in a RESPONSE FILE with every path QUOTED -- see the header comment.
{
  echo '--target=thumbv7-unknown-windows-msvc'
  echo "-vctoolsdir \"$VCTOOLS\""
  echo "-winsdkdir \"$WINSDK\""
  echo '-winsdkversion 10.0.19041.0'
  echo "/FI\"$ADB_ROOT_W/cross/clang-cl-arm-shim.h\""
  echo "/FI\"$ADB_ROOT_W/cross/adb-stl-gaps.h\""
  echo '/std:c++20'
  echo '/EHsc'
  echo '-ferror-limit=0'
  echo '/DADB_HOST=1 /DUNICODE=1 /D_UNICODE=1 /D_GNU_SOURCE /D_POSIX_SOURCE'
  echo '/DANDROID_BASE_UNIQUE_FD_DISABLE_IMPLICIT_CONVERSION=1'
  echo '/D_CRT_SECURE_NO_WARNINGS /DWIN32_LEAN_AND_MEAN /DNOMINMAX'
  # NOTE: _FILE_OFFSET_BITS=64 was tried here and is WRONG on UCRT -- see the long comment
  # in cross/msvc-posix-compat/sys/stat.h. wstat is aliased there instead, size-matched to
  # whatever `struct stat` really is.
  echo "-I\"$ADB_ROOT_W/deps/adb-35.0.2\""
  echo "-I\"$ADB_ROOT_W/deps/libbase/include\""
  # in-tree adb modules: crypto/, tls/, pairing_*/ each export headers under <adb/...>
  echo "-I\"$ADB_ROOT_W/deps/adb-35.0.2/crypto/include\""
  echo "-I\"$ADB_ROOT_W/deps/adb-35.0.2/tls/include\""
  echo "-I\"$ADB_ROOT_W/deps/adb-35.0.2/pairing_auth/include\""
  echo "-I\"$ADB_ROOT_W/deps/adb-35.0.2/pairing_connection/include\""
  echo "-I\"$ADB_ROOT_W/deps/boringssl-pinned/include\""
  echo "-I\"$ADB_ROOT_W/deps/protobuf-3.21.12/src\""
  # usb_libusb.cpp spells it <libusb/libusb.h>, so the root is the -I, not libusb/
  echo "-I\"$ADB_ROOT_W/deps/libusb-1.0.28\""
  echo "-I\"$ADB_ROOT_W/deps/libusb-1.0.28/libusb\""
  echo "-I\"$ADB_ROOT_W/build/adb-protos/lite\""
  echo "-I\"$ADB_ROOT_W/build/adb-protos/full\""
  # LAST: the mingw-gap compat headers. Never shadows a real UCRT header.
  echo "-I\"$ADB_ROOT_W/cross/msvc-posix-compat\""
  # verified-minimal stand-ins for absent AOSP modules (see cross/aosp-stubs/README.md)
  echo "-I\"$ADB_ROOT_W/cross/aosp-stubs\""
} > "$OUT/pin.rsp"
mkdir -p "$OUT/log"; rm -rf "$OUT/log"; mkdir -p "$OUT/log"

V=$("$RT2/clang-cl.exe" --version | head -1)
case "$V" in *23.1.1-rt2*) echo "GATE OK: $V" ;; *) echo "GATE FAIL: $V"; exit 1 ;; esac

# ---- SYSROOT SELF-TEST ----
printf '#include <string>\n#include <errno.h>\n#include <bit>\nint main(){std::string s="x";return (int)s.size()+errno;}\n' > "$OUT/probe.cpp"
if ! "$RT2/clang-cl.exe" "@$RSP" -fsyntax-only "$(cygpath -w "$OUT/probe.cpp")" >"$OUT/probe.log" 2>&1; then
  echo "!!! SYSROOT SELF-TEST FAILED - the compiler cannot compile #include <string>."
  echo "    This is a TOOL/INVOCATION fault, NOT a finding about adb. Nothing below is evidence."
  head -10 "$OUT/probe.log"; exit 2
fi
echo "sysroot self-test OK (<string>, <errno.h>, <bit> all resolve)"

# ---- the four Soong lists, verbatim (Android.bp 212-250, 265-300, 412-432) ----
LIBADB_SRCS="adb.cpp adb_io.cpp adb_listeners.cpp adb_mdns.cpp adb_trace.cpp adb_unique_fd.cpp adb_utils.cpp fdevent/fdevent.cpp services.cpp sockets.cpp socket_spec.cpp sysdeps/env.cpp sysdeps/errno.cpp transport.cpp transport_fd.cpp types.cpp"
LIBADB_WINDOWS_SRCS="fdevent/fdevent_poll.cpp sysdeps_win32.cpp sysdeps/win32/errno.cpp sysdeps/win32/stat.cpp"
LIBADB_HOST_EXTRA="client/openscreen/mdns_service_info.cpp client/openscreen/mdns_service_watcher.cpp client/openscreen/platform/logging.cpp client/openscreen/platform/task_runner.cpp client/openscreen/platform/udp_socket.cpp client/auth.cpp client/adb_wifi.cpp client/usb_libusb.cpp client/transport_local.cpp client/mdnsresponder_client.cpp client/mdns_utils.cpp client/transport_mdns.cpp client/transport_usb.cpp client/pairing/pairing_client.cpp client/usb_windows.cpp"
ADB_BINARY_SRCS="client/adb_client.cpp client/bugreport.cpp client/commandline.cpp client/file_sync_client.cpp client/main.cpp client/console.cpp client/adb_install.cpp client/line_printer.cpp client/fastdeploy.cpp client/fastdeploycallbacks.cpp client/incremental.cpp client/incremental_server.cpp client/incremental_utils.cpp shell_service_protocol.cpp"
ALL="$LIBADB_SRCS $LIBADB_WINDOWS_SRCS $LIBADB_HOST_EXTRA $ADB_BINARY_SRCS"

OK=0; FAIL=0; ABSENT=0; N=0
: > "$OUT/missing-headers.txt"; : > "$OUT/real-errors.txt"; : > "$OUT/summary.txt"

for f in $ALL; do
  N=$((N+1))
  if [ ! -f "$S/$f" ]; then
    printf '%-46s NO SUCH SOURCE\n' "$f" | tee -a "$OUT/summary.txt"; ABSENT=$((ABSENT+1)); continue
  fi
  LOG="$OUT/log/$(echo "$f" | tr '/' '_').log"
  "$RT2/clang-cl.exe" "@$RSP" -fsyntax-only "$(cygpath -w "$S/$f")" > "$LOG" 2>&1
  if [ $? -eq 0 ]; then
    OK=$((OK+1)); printf '%-46s OK\n' "$f" | tee -a "$OUT/summary.txt"
  else
    FAIL=$((FAIL+1))
    NE=$(grep -c 'error:' "$LOG")
    # Rank by the FIRST error IN ORDER. Taking any 'file not found' anywhere in the log
    # mis-ranked 26 files as "missing utime.h" when their real first failure was 141 errors
    # earlier, out of the Windows SDK's mswsockdef.h.
    FIRST=$(grep -m1 -E 'error:' "$LOG")
    H=$(echo "$FIRST" | grep -oE "'[^']+' file not found" | sed "s/' file not found//;s/^'//")
    if [ -n "$H" ]; then
      printf '%-46s MISSING HEADER  %-34s (%s errors)\n' "$f" "$H" "$NE" | tee -a "$OUT/summary.txt"
      echo "$H" >> "$OUT/missing-headers.txt"
    else
      E=$(echo "$FIRST" | sed 's/^.*error: //' | cut -c1-80)
      printf '%-46s ERROR(%s)  %s\n' "$f" "$NE" "$E" | tee -a "$OUT/summary.txt"
      echo "$f :: ($NE errors) $E" >> "$OUT/real-errors.txt"
    fi
  fi
done

echo
echo "################ D4 TOTALS ################"
echo "sources in the Soong lists = $N   (denominator)"
echo "  compiled clean            = $OK"
echo "  failed                    = $FAIL"
echo "  source file absent        = $ABSENT"
echo
echo "---- missing headers, by how many files need them ----"
sort "$OUT/missing-headers.txt" | uniq -c | sort -rn
echo
echo "---- errors that are NOT a missing header (the real porting blockers) ----"
if [ -s "$OUT/real-errors.txt" ]; then cat "$OUT/real-errors.txt"; else echo "   (none)"; fi
