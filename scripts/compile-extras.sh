#!/bin/sh
# adb-rt: compile the pieces adb links that are neither in the 49 Soong sources nor a
# prebuilt library: the GENERATED .pb.cc, and adb's own in-tree modules
# (crypto/ tls/ pairing_auth/ pairing_connection/), which are separate Soong modules.
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
G=$ADB_ROOT/build/adb-protos
OUT=$ADB_ROOT/build/adb-extras
rm -rf "$OUT"; mkdir -p "$OUT/obj" "$OUT/log"
sh $ADB_ROOT/scripts/pin-rsp.sh > "$OUT/pin.rsp"
echo "-I\"$ADB_ROOT_W/deps/libbase\"" >> "$OUT/pin.rsp"
RSP="$(cygpath -w "$OUT/pin.rsp")"

OK=0; FAIL=0; N=0
: > "$OUT/failed.txt"
run() {   # run <label> <abs-source>
  N=$((N+1)); lbl="$1"; src="$2"
  flat=$(echo "$lbl" | tr '/' '_')
  "$RT2/clang-cl.exe" "@$RSP" /c "$(cygpath -w "$src")" "/Fo$(cygpath -w "$OUT/obj/$flat.obj")" > "$OUT/log/$flat.log" 2>&1
  if [ $? -eq 0 ] && [ -f "$OUT/obj/$flat.obj" ]; then OK=$((OK+1)); else
    FAIL=$((FAIL+1))
    printf '%-46s %s\n' "$lbl" "$(grep -m1 -E 'error:' "$OUT/log/$flat.log" | sed 's/^.*error: //' | cut -c1-80)" >> "$OUT/failed.txt"
  fi
}

for f in $(find "$G" -name '*.pb.cc'); do run "proto_$(basename "$f")" "$f"; done
for f in crypto/key.cpp crypto/rsa_2048_key.cpp crypto/x509_generator.cpp \
         tls/adb_ca_list.cpp tls/tls_connection.cpp \
         pairing_auth/aes_128_gcm.cpp pairing_auth/pairing_auth.cpp \
         pairing_connection/pairing_connection.cpp; do
  run "$f" "$S/$f"
done

echo "extras = $N (denominator)   built = $OK   failed = $FAIL"
[ -s "$OUT/failed.txt" ] && { echo "--- failures ---"; cat "$OUT/failed.txt"; }
exit 0
