// aosp-stubs: cutils/sockets.h — ENUM ONLY.
//
// MEASURED, not assumed. 8 of the Windows-compiled sources include this header:
//   adb_listeners.cpp  services.cpp  socket_spec.cpp  sysdeps_win32.cpp
//   client/adb_client.cpp  client/console.cpp  client/transport_local.cpp
//   client/pairing/pairing_client.cpp
// A sweep for every public cutils socket symbol (socket_local_client/server,
// socket_network_client[_timeout], socket_loopback_client/server, socket_inaddr_any_server,
// socket_get_local_port, socket_peer_is_trusted, android_get_control_socket) found:
//   * socket_spec.cpp  -> ANDROID_SOCKET_NAMESPACE_{ABSTRACT,RESERVED,FILESYSTEM} only
//   * the other 7      -> NO symbol from this header at all (vestigial includes)
// and socket_spec.cpp uses them purely as compile-time table values, every Windows entry
// gated !ADB_WINDOWS (socket_spec.cpp:66-76), so no cutils function is reachable on Windows.
//
// The files that DO call real cutils socket functions -- daemon/services.cpp,
// daemon/transport_local.cpp, pairing_connection/pairing_server.cpp,
// sysdeps/posix/network.cpp, and the *_test.cpp -- are device-only, POSIX-only
// (Android.bp `not_windows`), or test-only, and are NOT in the host adb.exe link graph.
//
// => ZERO libcutils .cpp files need to be compiled or linked for Windows adb, and no adb
//    functionality is lost: adb's Windows path has always used its own Winsock code
//    (sysdeps_win32.cpp), with network_local_client/server defined as abort() stubs.
//
// Values are AOSP's, from system/core/libcutils/include/cutils/sockets.h.
#ifndef ADBRT_STUB_CUTILS_SOCKETS_H
#define ADBRT_STUB_CUTILS_SOCKETS_H
enum android_socket_namespace {
    ANDROID_SOCKET_NAMESPACE_ABSTRACT   = 0,
    ANDROID_SOCKET_NAMESPACE_RESERVED   = 1,
    ANDROID_SOCKET_NAMESPACE_FILESYSTEM = 2,
};
#endif
