#!/bin/sh
# adb-rt §1 (BATCH-ADB-2B): compile adb's Soong sources to REAL OBJECTS.
#
# D4 used -fsyntax-only, which emits NO object -- so it could not produce an undefined-symbol
# set. This compiles for real (/c), keeps going, and may surface codegen errors that
# syntax-only hid. That is a legitimate finding, not a regression.
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
OUT=$ADB_ROOT/build/adb-obj
rm -rf "$OUT"; mkdir -p "$OUT/obj" "$OUT/log"

V=$("$RT2/clang-cl.exe" --version | head -1)
case "$V" in *23.1.1-rt2*) echo "GATE OK: $V" ;; *) echo "GATE FAIL: $V"; exit 1 ;; esac

sh $ADB_ROOT/scripts/pin-rsp.sh > "$OUT/pin.rsp"
RSP="$(cygpath -w "$OUT/pin.rsp")"

# sysroot self-test -- a compiler with no sysroot reports "missing errno.h" for everything
printf '#include <string>\nint main(){return (int)std::string("x").size();}\n' > "$OUT/probe.cpp"
if ! "$RT2/clang-cl.exe" "@$RSP" -fsyntax-only "$(cygpath -w "$OUT/probe.cpp")" >"$OUT/probe.log" 2>&1; then
  echo "!!! SYSROOT SELF-TEST FAILED - tool/invocation fault, NOT a finding about adb"; head -8 "$OUT/probe.log"; exit 2
fi
echo "sysroot self-test OK"

LIBADB_SRCS="adb.cpp adb_io.cpp adb_listeners.cpp adb_mdns.cpp adb_trace.cpp adb_unique_fd.cpp adb_utils.cpp fdevent/fdevent.cpp services.cpp sockets.cpp socket_spec.cpp sysdeps/env.cpp sysdeps/errno.cpp transport.cpp transport_fd.cpp types.cpp"
LIBADB_WINDOWS_SRCS="fdevent/fdevent_poll.cpp sysdeps_win32.cpp sysdeps/win32/errno.cpp sysdeps/win32/stat.cpp"
# EXCLUDED, replaced by cross/aosp-stubs/compat/mdns-stub.cpp (READING T4):
#   client/openscreen/mdns_service_info.cpp     client/openscreen/mdns_service_watcher.cpp
#   client/openscreen/platform/logging.cpp      client/openscreen/platform/task_runner.cpp
#   client/openscreen/platform/udp_socket.cpp   client/mdnsresponder_client.cpp
#   client/transport_mdns.cpp
# mDNS cannot be removed by a flag (ADB_MDNS is a RUNTIME env var), so the 9 declared entry
# points are satisfied by the stub instead. Drops libmdnssd + both openscreen modules.
# client/usb_windows.cpp is also excluded: AdbWinApi is replaced by the libusb backend.
LIBADB_HOST_EXTRA="client/auth.cpp client/adb_wifi.cpp client/usb_libusb.cpp client/transport_local.cpp client/mdns_utils.cpp client/transport_usb.cpp client/pairing/pairing_client.cpp"
ADB_BINARY_SRCS="client/adb_client.cpp client/bugreport.cpp client/commandline.cpp client/file_sync_client.cpp client/main.cpp client/console.cpp client/adb_install.cpp client/line_printer.cpp client/fastdeploy.cpp client/fastdeploycallbacks.cpp client/incremental.cpp client/incremental_server.cpp client/incremental_utils.cpp shell_service_protocol.cpp"
ALL="$LIBADB_SRCS $LIBADB_WINDOWS_SRCS $LIBADB_HOST_EXTRA $ADB_BINARY_SRCS"

OK=0; FAIL=0; N=0
: > "$OUT/failed.txt"; : > "$OUT/built.txt"
for f in $ALL; do
  N=$((N+1))
  flat=$(echo "$f" | tr '/' '_')
  LOG="$OUT/log/$flat.log"
  "$RT2/clang-cl.exe" "@$RSP" /c "$(cygpath -w "$S/$f")" "/Fo$(cygpath -w "$OUT/obj/$flat.obj")" > "$LOG" 2>&1
  if [ $? -eq 0 ] && [ -f "$OUT/obj/$flat.obj" ]; then
    OK=$((OK+1)); echo "$f" >> "$OUT/built.txt"
  else
    FAIL=$((FAIL+1))
    E=$(grep -m1 -E 'error:' "$LOG" | sed 's/^.*error: //' | cut -c1-80)
    printf '%-46s %s\n' "$f" "$E" >> "$OUT/failed.txt"
  fi
done

echo
echo "sources = $N (denominator)   objects built = $OK   failed = $FAIL"
echo "objects on disk = $(find "$OUT/obj" -name '*.obj' | wc -l)"
echo
echo "--- failures ---"
cat "$OUT/failed.txt"
