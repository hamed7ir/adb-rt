// adb-rt: mDNS stub -- replaces client/transport_mdns.cpp and client/mdnsresponder_client.cpp.
//
// WHY THIS EXISTS (READING T4). mDNS cannot be compiled out of adb with a flag:
// client/main.cpp:135 reads
//     if (!getenv("ADB_MDNS") || strcmp(getenv("ADB_MDNS"), "0") != 0) {
//         init_mdns_transport_discovery();
//     }
// ADB_MDNS is a RUNTIME environment variable, so the symbol reference is emitted regardless.
// Ground truth agrees: 4 mDNS symbols sit in the undefined set of our compiled objects, and
// client_main.cpp.obj is the object that references init_mdns_transport_discovery.
//
// The entire mDNS surface is defined in just two files -- client/transport_mdns.cpp (needs
// openscreen) and client/mdnsresponder_client.cpp (needs Apple's dns_sd.h). Because this build
// uses its own source list rather than Soong, those two are replaced by this file, which
// satisfies the linker with honest no-ops.
//
// WHAT THIS BUYS: libmdnssd, libopenscreen-discovery and libopenscreen-platform-impl are no
// longer needed -- 3 of the 16 missing dependencies -- and 7 of the 18 failing sources stop
// being sources (5 client/openscreen/* glue files plus those 2).
//
// WHAT IT COSTS, stated plainly: no mDNS discovery, no `adb mdns check` / `adb mdns services`,
// and `adb pair` loses service discovery (the SPAKE2 pairing crypto itself is present in our
// BoringSSL and is unaffected). Per BATCH-ADB-2B §9 that is ADB-3's inheritance; ADB-2's
// deliverable is CNXN+AUTH.
//
// Every function here returns a value that means "not available", never a fake success.
#include "adb_mdns.h"

#include <optional>
#include <string>
#include <string_view>

// Declared in transport.h, defined in client/transport_mdns.cpp upstream. Declared locally so
// this stub does not have to pull transport.h and its whole dependency cone.
void init_mdns_transport_discovery();
bool using_bonjour(void);

void init_mdns_transport_discovery() {
    // No-op. Discovery is unavailable in this build.
}

void mdns_cleanup() {}

// Declared in transport.h:488, defined upstream in client/transport_mdns.cpp:240 alongside the
// rest of the mDNS surface. adb.cpp:1337 calls it, so the stub owes it too.
// Always false: without discovery there is no Bonjour backend in use.
bool using_bonjour(void) { return false; }

std::string mdns_check() {
    return "ERROR: mdns discovery is not compiled into this build of adb "
           "(adb-rt armv7-windows-msvc; see cross/aosp-stubs/compat/mdns-stub.cpp)";
}

std::string mdns_list_discovered_services() {
    return "";
}

std::optional<MdnsInfo> mdns_get_connect_service_info(const std::string& /*name*/) {
    return std::nullopt;
}

std::optional<MdnsInfo> mdns_get_pairing_service_info(const std::string& /*name*/) {
    return std::nullopt;
}

bool adb_secure_connect_by_service_name(const std::string& /*instance_name*/) {
    return false;
}

// NOT defined here: adb_DNSServiceIndexByName and adb_DNSServiceShouldAutoConnect.
// Measured at the link: adb_mdns.cpp (one of the 49 sources we compile) already defines both,
// and providing them here produced
//     lld-link: error: duplicate symbol: adb_DNSServiceIndexByName(...)
// They are declared in adb_mdns.h alongside the rest of the surface, which is what made them
// look like part of the gap. They are not.
