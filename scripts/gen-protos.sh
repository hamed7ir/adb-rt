#!/bin/sh
# adb-rt: generate adb's .pb.cc/.pb.h with the HOST protoc, each module at the runtime
# proto/Android.bp declares for it. NOT all lite -- see the table in STAGE-2-RESULTS.md.
set -eu
export MSYS2_ARG_CONV_EXCL='*'
PROTOC="$ADB_ROOT_W/build/protoc-host/protoc.exe"
S=$ADB_ROOT/deps/adb-35.0.2
G=$ADB_ROOT/build/adb-protos
rm -rf "$G"; mkdir -p "$G/lite" "$G/full"

W() { cygpath -w "$1"; }

# libadb_protos -- type: "lite"  (proto/Android.bp:25-42)
"$PROTOC" --proto_path="$(W "$S/proto")" --cpp_out="lite:$(W "$G/lite")" \
    "$(W "$S/proto/adb_known_hosts.proto")" "$(W "$S/proto/key_type.proto")" "$(W "$S/proto/pairing.proto")"

# libadb_host_protos -- type: "full"  (proto/Android.bp:181-187)
# libapp_processes_protos_full -- type: "full"  (proto/Android.bp:138-144)
"$PROTOC" --proto_path="$(W "$S/proto")" --cpp_out="$(W "$G/full")" \
    "$(W "$S/proto/adb_host.proto")" "$(W "$S/proto/app_processes.proto")"

# libfastdeploy_host -- type: "lite"  (Android.bp:1005-1008)
# proto_path is the ADB ROOT so the generated header keeps its "fastdeploy/proto/" prefix,
# which is how client/fastdeploy.cpp and client/adb_install.cpp spell the include.
"$PROTOC" --proto_path="$(W "$S")" --cpp_out="lite:$(W "$G/lite")" \
    "$(W "$S/fastdeploy/proto/ApkEntry.proto")"

echo "--- generated ---"
find "$G" -name '*.pb.h' | sed "s|$G/|   |"
echo "--- runtime check: base class per generated header ---"
for f in $(find "$G" -name '*.pb.h'); do
  lite=$(grep -c 'MessageLite' "$f"); full=$(grep -cE 'public ::PROTOBUF_NAMESPACE_ID::Message\b' "$f")
  printf '   %-46s MessageLite=%-3s Message=%s\n' "$(echo "$f" | sed "s|$G/||")" "$lite" "$full"
done
