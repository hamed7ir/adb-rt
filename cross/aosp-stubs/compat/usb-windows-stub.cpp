// adb-rt: stand-in for client/usb_windows.cpp (the AdbWinApi backend).
//
// WHY. adb ships TWO Windows USB backends and Android.bp compiles BOTH into libadb_host:
//   * client/usb_windows.cpp  -- AdbWinApi.dll, a separate AOSP repo (development/host/windows)
//                                that needs ATL and has only ever been built for x86
//   * client/usb_libusb.cpp   -- libusb, which we DO have, built for ARM32
// client/usb.h declares seven usb_* entry points in the GLOBAL namespace and only usb_init in
// `namespace libusb`. usb_libusb.cpp therefore defines exactly one symbol, libusb::usb_init
// (verified with llvm-nm on its object) -- the other seven come from usb_windows.cpp.
//
// transport_usb.cpp's UsbConnection references the global ones unconditionally, so excluding
// usb_windows.cpp leaves them undefined even though nothing calls them on the libusb path.
// This file satisfies the linker.
//
// ⚠⚠ BEHAVIOURAL CONSEQUENCE, AND IT IS NOT SMALL:
// is_libusb_enabled() (client/transport_usb.cpp:180) defaults to FALSE on _WIN32 and is only
// flipped by the ADB_LIBUSB environment variable. So in THIS build:
//
//        USB REQUIRES  ADB_LIBUSB=1  IN THE ENVIRONMENT.
//
// Without it adb takes the AdbWinApi path, lands here, and reports that the backend is absent
// instead of silently doing nothing. TCP/IP (`adb connect`) is unaffected.
//
// These functions therefore do NOT pretend to succeed: usb_init() explains the situation on
// stderr once, and the I/O entry points return failure. A stub that returned success would
// make adb hang waiting for a device that can never arrive.
#include "client/usb.h"

#include <stdio.h>

namespace {
bool g_warned = false;
void WarnOnce() {
    if (g_warned) return;
    g_warned = true;
    fprintf(stderr,
            "adb: the AdbWinApi USB backend is not built in this ARM32 build.\n"
            "adb: set ADB_LIBUSB=1 to use the libusb backend, or use TCP/IP (adb connect).\n");
    fflush(stderr);
}
}  // namespace

void usb_init() { WarnOnce(); }

void usb_cleanup() {}

int usb_write(usb_handle* /*h*/, const void* /*data*/, int /*len*/) {
    WarnOnce();
    return -1;
}

int usb_read(usb_handle* /*h*/, void* /*data*/, int /*len*/) {
    WarnOnce();
    return -1;
}

int usb_close(usb_handle* /*h*/) { return -1; }

void usb_reset(usb_handle* /*h*/) {}

void usb_kick(usb_handle* /*h*/) {}

size_t usb_get_max_packet_size(usb_handle* /*h*/) { return 0; }
