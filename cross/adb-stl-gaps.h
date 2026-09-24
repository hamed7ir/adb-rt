// adb-rt: standard headers adb relies on TRANSITIVELY under libc++, force-included for the
// MSVC STL. Adding a standard header via /FI changes no source file: zero source patches.
//
// AOSP pins `stl: "libc++_static"` for every adb module, and libc++ pulls <array> in through
// <string_view>. The MSVC STL does not, so client/mdns_utils.cpp:47 fails with
// "implicit instantiation of undefined template 'std::array<std::basic_string<char>, 2>'"
// while including only <optional>, <string_view> and <android-base/strings.h>.
//
// This file is adb-only -- it is NOT the ARM intrinsics shim, which the C dependencies
// (libusb, BoringSSL) also force-include.
#ifndef ADBRT_STL_GAPS_H
#define ADBRT_STL_GAPS_H
#ifdef __cplusplus
// <array>  -- client/mdns_utils.cpp:47 uses std::array with only <optional>/<string_view>
// <string> -- crypto/include/adb/crypto/x509_generator.h:28 uses std::string but includes
//             only <openssl/x509v3.h>; libc++ pulls <string> in transitively, MSVC does not.
#include <array>
#include <string>
#endif
#endif
