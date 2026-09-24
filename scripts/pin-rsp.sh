#!/bin/sh
# adb-rt: emit the ARM32 clang-cl pin as a RESPONSE FILE on stdout.
# Single source of truth -- scripts/catalogue-adb.sh and scripts/compile-adb-objects.sh both
# use this, so the syntax-only catalogue and the real object build can never drift apart.
#
# /EHs-c- -- EXCEPTIONS OFF. NOT a style choice:
#   clang-cl /EHsc on thumbv7-windows-msvc dies with
#     "fatal error: error in backend: WinEH not implemented for this target"
#   LLVM has no Windows-EH codegen for ARM32. Measured: /EHsc -> exit 1, 0-byte object;
#   /EHs-c- -> exit 0, 225,993-byte object, on the same source.
#   Safe here: no host adb source contains try/catch/throw (sysdeps_win32.cpp only MENTIONS
#   throw in two comments), and BoringSSL + protobuf-lite were ALREADY built with no /EH flag,
#   so this makes the whole ARM32 object set consistent rather than mixing EH models.
#
# Every path is QUOTED. Passing these through an unquoted shell variable word-splits
# "D:/Program Files/..." and silently produces a compiler with NO SYSROOT.
cat <<RSP
--target=thumbv7-unknown-windows-msvc
-vctoolsdir "$VCTOOLS"
-winsdkdir "$WINSDK"
-winsdkversion 10.0.19041.0
/FI"$ADB_ROOT_W/cross/clang-cl-arm-shim.h"
/FI"$ADB_ROOT_W/cross/adb-stl-gaps.h"
/std:c++20
/EHs-c-
/MT
-ferror-limit=0
/DADB_HOST=1 /DUNICODE=1 /D_UNICODE=1 /D_GNU_SOURCE /D_POSIX_SOURCE
/DANDROID_BASE_UNIQUE_FD_DISABLE_IMPLICIT_CONVERSION=1
/D_CRT_SECURE_NO_WARNINGS /DWIN32_LEAN_AND_MEAN /DNOMINMAX
-I"$ADB_ROOT_W/deps/adb-35.0.2"
-I"$ADB_ROOT_W/deps/libbase/include"
-I"$ADB_ROOT_W/deps/adb-35.0.2/crypto/include"
-I"$ADB_ROOT_W/deps/adb-35.0.2/tls/include"
-I"$ADB_ROOT_W/deps/adb-35.0.2/pairing_auth/include"
-I"$ADB_ROOT_W/deps/adb-35.0.2/pairing_connection/include"
-I"$ADB_ROOT_W/deps/boringssl-pinned/include"
-I"$ADB_ROOT_W/deps/protobuf-3.21.12/src"
-I"$ADB_ROOT_W/deps/libusb-1.0.28"
-I"$ADB_ROOT_W/deps/libusb-1.0.28/libusb"
-I"$ADB_ROOT_W/build/gen-include"
-I"$ADB_ROOT_W/build/adb-protos/lite"
-I"$ADB_ROOT_W/build/adb-protos/full"
-I"$ADB_ROOT_W/cross/msvc-posix-compat"
-I"$ADB_ROOT_W/deps/libdiagnose_usb/include"
-I"$ADB_ROOT_W/deps/libcrypto_utils/include"
-I"$ADB_ROOT_W/deps/lz4-1.9.4/lib"
-I"$ADB_ROOT_W/deps/brotli-1.1.0/c/include"
-I"$ADB_ROOT_W/deps/zstd-1.5.6/lib"
-I"$ADB_ROOT_W/cross/aosp-stubs"
RSP
