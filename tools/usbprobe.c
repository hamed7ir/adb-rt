/*
 * adb-rt usbprobe -- BATCH-ADB-6 §2, extended after TRIP-6.
 *
 * A standalone instrument for libusb. It is NOT adb: no server, no environment variables,
 * no kill-server, one window, prints and exits.
 *
 * Why it exists: three device trips were spent on instruments that could not separate their
 * own failure from the thing they were measuring. This one can only fail in ways it names.
 *
 * THE GATE (§2): HAS_HOTPLUG must be 1.
 *
 * ⚠ ...but that alone is NOT sufficient, and this probe says so. libusb 1.0.28's
 * usbi_alloc_device() attaches a device to the context only when
 *     !libusb_has_capability(LIBUSB_CAP_HAS_HOTPLUG)
 * (core.c:725). The moment the capability is 1, the CORE stops attaching devices and the
 * BACKEND has to do it. If the backend rework is missing or wrong, HAS_HOTPLUG prints 1 and
 * the device list is EMPTY -- a build that passes the stated gate and can never see a phone.
 * So the verdict below requires HAS_HOTPLUG == 1 *and* a non-empty device list.
 *
 * ===========================================================================================
 * TRIP-6 ADDITION -- "libusb_open succeeded" IS NOT "adb will work".
 *
 * TRIP-6 fixed libusb_open on the composite (file-transfer) mode by adding the missing
 * DeviceInterfaceGUIDs registry value: -5 became 0. adb still listed no device. The old probe
 * stopped at libusb_open, so it could not tell us why -- it was measuring less than adb does.
 *
 * So this probe now replays adb's ENTIRE LibusbConnection::OpenDevice sequence, in order, and
 * names the first call that fails:
 *
 *   adb-35.0.2/client/usb_libusb.cpp:588  OpenDevice()
 *     :594  libusb_open
 *     :604  libusb_get_device_descriptor
 *     :366  FindInterface        -- needs bDeviceClass == 0, one altsetting, 2 bulk endpoints
 *     :470  GetSerial            -- libusb_get_string_descriptor_ascii == a CONTROL TRANSFER
 *     :624  libusb_claim_interface
 *     :632  libusb_clear_halt    on both endpoints
 *
 * and then, if all of that passes, sends a real ADB CNXN packet and waits for the reply. If
 * the phone answers, adb's transport layer has nothing left to fail at, and any remaining
 * problem is above the USB layer.
 * ===========================================================================================
 */

#include <stdio.h>
#include <string.h>

#include "libusb.h"

#define ADB_VID 0x0E8D /* MediaTek. Change this to match your handset's USB vendor ID. */

/* adb protocol, from adb-35.0.2/protocol.txt and adb.h */
#define A_CNXN    0x4e584e43u
#define A_AUTH    0x48545541u
#define A_VERSION 0x01000001u
#define A_MAXDATA 0x00040000u

static const char *speed_str(int s)
{
	switch (s) {
	case LIBUSB_SPEED_LOW:        return "low";
	case LIBUSB_SPEED_FULL:       return "full";
	case LIBUSB_SPEED_HIGH:       return "high";
	case LIBUSB_SPEED_SUPER:      return "super";
	case LIBUSB_SPEED_SUPER_PLUS: return "super+";
	default:                      return "unknown";
	}
}

static int is_adb_iface(const struct libusb_interface_descriptor *id)
{
	return id->bInterfaceClass == 0xFF &&
	       id->bInterfaceSubClass == 0x42 &&
	       id->bInterfaceProtocol == 0x01;
}

static int LIBUSB_CALL hotplug_cb(libusb_context *ctx, libusb_device *dev,
                                  libusb_hotplug_event event, void *user_data)
{
	int *fired = (int *)user_data;
	(void)ctx; (void)dev; (void)event;
	if (fired)
		(*fired)++;
	return 0;
}

static void put32(unsigned char *p, unsigned int v)
{
	p[0] = (unsigned char)(v & 0xff);
	p[1] = (unsigned char)((v >> 8) & 0xff);
	p[2] = (unsigned char)((v >> 16) & 0xff);
	p[3] = (unsigned char)((v >> 24) & 0xff);
}

static unsigned int get32(const unsigned char *p)
{
	return (unsigned int)p[0] | ((unsigned int)p[1] << 8) |
	       ((unsigned int)p[2] << 16) | ((unsigned int)p[3] << 24);
}

/*
 * Replay adb's OpenDevice() on an already-open handle.
 * Returns 0 if every step adb takes would have succeeded, non-zero otherwise.
 */
static int replay_adb_open(libusb_device *dev, libusb_device_handle *h,
                           const struct libusb_device_descriptor *dd)
{
	struct libusb_config_descriptor *cfg = NULL;
	const struct libusb_interface_descriptor *adb_id = NULL;
	unsigned char serial[256];
	unsigned char hdr[24], payload[8], reply[24];
	unsigned char bulk_in = 0, bulk_out = 0;
	int iface_index = -1, iface_number = -1;
	int found_in = 0, found_out = 0;
	int rc, j, k, transferred;
	unsigned int cmd, crc;

	printf("\n      --- adb OpenDevice() replay ---\n");

	/* usb_libusb.cpp:367 -- adb rejects anything whose device class is not per-interface */
	printf("      bDeviceClass            = 0x%02x  %s\n", dd->bDeviceClass,
	       dd->bDeviceClass == LIBUSB_CLASS_PER_INTERFACE
	           ? "OK (adb requires 0x00)"
	           : "FAIL -- adb: \"skipping device with incorrect class\"");
	if (dd->bDeviceClass != LIBUSB_CLASS_PER_INTERFACE)
		return 1;

	rc = libusb_get_active_config_descriptor(dev, &cfg);
	if (rc != 0 || !cfg) {
		printf("      libusb_get_active_config_descriptor -> %d (%s)  FAIL\n",
		       rc, libusb_error_name(rc));
		return 1;
	}
	printf("      bNumInterfaces          = %d  (%s device)\n", cfg->bNumInterfaces,
	       cfg->bNumInterfaces > 1 ? "COMPOSITE" : "single-interface");

	/* usb_libusb.cpp:389 -- adb walks interfaces BY ARRAY INDEX and stores that index
	 * in interface_num_, which it later passes to libusb_claim_interface. */
	for (j = 0; j < cfg->bNumInterfaces; j++) {
		const struct libusb_interface *itf = &cfg->interface[j];
		if (itf->num_altsetting == 0)
			continue;
		if (!is_adb_iface(&itf->altsetting[0]))
			continue;
		if (itf->num_altsetting != 1) {
			printf("      interface %d has %d altsettings -- adb SKIPS it\n",
			       j, itf->num_altsetting);
			continue;
		}
		adb_id = &itf->altsetting[0];
		iface_index = j;
		iface_number = adb_id->bInterfaceNumber;
		for (k = 0; k < adb_id->bNumEndpoints; k++) {
			const struct libusb_endpoint_descriptor *ep = &adb_id->endpoint[k];
			if ((ep->bmAttributes & LIBUSB_TRANSFER_TYPE_MASK) != LIBUSB_TRANSFER_TYPE_BULK)
				continue;
			if ((ep->bEndpointAddress & LIBUSB_ENDPOINT_DIR_MASK) == LIBUSB_ENDPOINT_OUT) {
				if (!found_out) { found_out = 1; bulk_out = ep->bEndpointAddress; }
			} else {
				if (!found_in)  { found_in = 1;  bulk_in  = ep->bEndpointAddress; }
			}
		}
		if (found_in && found_out)
			break;
		printf("      interface %d: missing bulk endpoints (in=%d out=%d) -- adb REJECTS it\n",
		       j, found_in, found_out);
		adb_id = NULL;
	}

	if (!adb_id) {
		printf("      FindInterface            -> FAIL  adb: \"failed to find adb interface\"\n");
		libusb_free_config_descriptor(cfg);
		return 1;
	}
	printf("      FindInterface            -> OK   array index %d, bInterfaceNumber %d\n",
	       iface_index, iface_number);
	if (iface_index != iface_number)
		printf("      !! index %d != bInterfaceNumber %d -- adb claims the INDEX\n",
		       iface_index, iface_number);
	printf("      endpoints                -> bulk_in = 0x%02x, bulk_out = 0x%02x\n",
	       bulk_in, bulk_out);
	libusb_free_config_descriptor(cfg);

	/* usb_libusb.cpp:470 GetSerial -- a control transfer, the first real traffic */
	memset(serial, 0, sizeof(serial));
	rc = libusb_get_string_descriptor_ascii(h, dd->iSerialNumber, serial, sizeof(serial) - 1);
	printf("      get_string_descriptor    -> %d %s\n", rc,
	       rc > 0 ? (const char *)serial : libusb_error_name(rc));
	if (rc <= 0) {
		printf("      ^^ CONTROL TRANSFER FAILED. adb logs \"failed to get serial from device\"\n");
		printf("         and continues with an empty serial -- this alone may not stop adb,\n");
		printf("         but on a composite device it points at the control-transfer path.\n");
	}

	/* usb_libusb.cpp:624 */
	rc = libusb_claim_interface(h, iface_index);
	printf("      libusb_claim_interface(%d)-> %d (%s)\n", iface_index, rc,
	       rc == 0 ? "OK" : libusb_error_name(rc));
	if (rc != 0) {
		if (rc == LIBUSB_ERROR_BUSY)
			printf("      ^^ BUSY: an adb server already holds it. Run adb-usb.cmd kill-server first.\n");
		printf("      ^^ THIS IS THE FAILURE. adb logs:\n");
		printf("         \"failed to claim adb interface for device '...': %s\"\n",
		       libusb_error_name(rc));
		return 1;
	}

	/* usb_libusb.cpp:632 -- both endpoints */
	rc = libusb_clear_halt(h, bulk_in);
	printf("      libusb_clear_halt(0x%02x)  -> %d (%s)\n", bulk_in, rc,
	       rc == 0 ? "OK" : libusb_error_name(rc));
	if (rc != 0) {
		printf("      ^^ THIS IS THE FAILURE. adb logs \"failed to clear halt\" and gives up.\n");
		libusb_release_interface(h, iface_index);
		return 1;
	}
	rc = libusb_clear_halt(h, bulk_out);
	printf("      libusb_clear_halt(0x%02x)  -> %d (%s)\n", bulk_out, rc,
	       rc == 0 ? "OK" : libusb_error_name(rc));
	if (rc != 0) {
		printf("      ^^ THIS IS THE FAILURE. adb logs \"failed to clear halt\" and gives up.\n");
		libusb_release_interface(h, iface_index);
		return 1;
	}

	printf("      => adb's OpenDevice() would SUCCEED on this device.\n");

	/* Beyond adb's OpenDevice: an actual CNXN, so a PASS here means the wire works. */
	printf("\n      --- ADB CNXN handshake (real traffic) ---\n");
	/* adb.cpp:300 send_connect(): payload is the banner with NO trailing NUL --
	 * cp->payload.assign(str.begin(), str.end()); data_length = payload.size().
	 * A_VERSION == A_VERSION_SKIP_CHECKSUM (adb.h:57-58), so data_crc32 is ignored,
	 * but we compute it honestly anyway. */
	memcpy(payload, "host::", 6);
	crc = 0;
	for (k = 0; k < 6; k++)
		crc += payload[k];
	put32(hdr +  0, A_CNXN);
	put32(hdr +  4, A_VERSION);
	put32(hdr +  8, A_MAXDATA);
	put32(hdr + 12, 6);
	put32(hdr + 16, crc);
	put32(hdr + 20, A_CNXN ^ 0xffffffffu);

	transferred = 0;
	rc = libusb_bulk_transfer(h, bulk_out, hdr, 24, &transferred, 3000);
	printf("      write CNXN header        -> %d (%s), %d bytes\n", rc,
	       rc == 0 ? "OK" : libusb_error_name(rc), transferred);
	if (rc == 0) {
		transferred = 0;
		rc = libusb_bulk_transfer(h, bulk_out, payload, 6, &transferred, 3000);
		printf("      write CNXN payload       -> %d (%s), %d bytes\n", rc,
		       rc == 0 ? "OK" : libusb_error_name(rc), transferred);
	}
	if (rc == 0) {
		memset(reply, 0, sizeof(reply));
		transferred = 0;
		rc = libusb_bulk_transfer(h, bulk_in, reply, 24, &transferred, 5000);
		printf("      read  reply              -> %d (%s), %d bytes\n", rc,
		       rc == 0 ? "OK" : libusb_error_name(rc), transferred);
		if (rc == 0 && transferred >= 4) {
			cmd = get32(reply);
			printf("      reply command            -> '%c%c%c%c' (0x%08x)  %s\n",
			       reply[0], reply[1], reply[2], reply[3], cmd,
			       cmd == A_AUTH ? "AUTH -- the phone is talking adb"
			                     : (cmd == A_CNXN ? "CNXN -- already authorised" : "unexpected"));
			printf("      => THE USB TRANSPORT WORKS END TO END IN THIS MODE.\n");
		}
	}
	if (rc != 0)
		printf("      ^^ the transport failed AFTER a successful claim -- note which call.\n");

	libusb_release_interface(h, iface_index);
	return 0;
}

int main(void)
{
	libusb_device **list = NULL;
	ssize_t n, i;
	int rc, hotplug, target_found = 0, adb_iface_found = 0, cb_fired = 0;
	int replay_attempted = 0, replay_ok = 0;
	libusb_hotplug_callback_handle handle;

	printf("adb-rt usbprobe -- libusb %s\n", "1.0.28 + windows hotplug backport");
	printf("================================================================\n");

	rc = libusb_init(NULL);
	printf("libusb_init                      -> %d (%s)\n",
	       rc, rc == 0 ? "OK" : libusb_error_name(rc));
	if (rc != 0) {
		printf("\nVERDICT: FAIL -- libusb_init failed; nothing below is meaningful.\n");
		return 2;
	}

	hotplug = libusb_has_capability(LIBUSB_CAP_HAS_HOTPLUG);
	printf("LIBUSB_CAP_HAS_HOTPLUG           -> %d %s\n", hotplug,
	       hotplug ? "(hotplug available)" : "(NO HOTPLUG -- adb will LOG(FATAL) and abort)");

	n = libusb_get_device_list(NULL, &list);
	printf("libusb_get_device_list           -> %d device(s)\n", (int)n);
	if (n < 0) {
		printf("\nVERDICT: FAIL -- device list error: %s\n", libusb_error_name((int)n));
		libusb_exit(NULL);
		return 2;
	}

	printf("\n--- devices ---\n");
	for (i = 0; i < n; i++) {
		struct libusb_device_descriptor dd;
		struct libusb_config_descriptor *cfg = NULL;
		libusb_device *dev = list[i];
		int j;

		if (libusb_get_device_descriptor(dev, &dd) != 0)
			continue;

		printf("bus %3u addr %3u  %04x:%04x  class %02x  speed %s\n",
		       libusb_get_bus_number(dev), libusb_get_device_address(dev),
		       dd.idVendor, dd.idProduct, dd.bDeviceClass,
		       speed_str(libusb_get_device_speed(dev)));

		if (libusb_get_active_config_descriptor(dev, &cfg) == 0 && cfg) {
			for (j = 0; j < cfg->bNumInterfaces; j++) {
				const struct libusb_interface *itf = &cfg->interface[j];
				int k;
				for (k = 0; k < itf->num_altsetting; k++) {
					const struct libusb_interface_descriptor *id = &itf->altsetting[k];
					printf("      iface %d.%d  class %02x/%02x/%02x%s\n",
					       id->bInterfaceNumber, id->bAlternateSetting,
					       id->bInterfaceClass, id->bInterfaceSubClass,
					       id->bInterfaceProtocol,
					       is_adb_iface(id) ? "   <-- ADB INTERFACE" : "");
					if (is_adb_iface(id))
						adb_iface_found = 1;
				}
			}
			libusb_free_config_descriptor(cfg);
		} else {
			printf("      (no active config descriptor)\n");
		}

		if (dd.idVendor == ADB_VID) {
			libusb_device_handle *h = NULL;
			int orc;
			target_found = 1;
			orc = libusb_open(dev, &h);
			printf("      libusb_open(%04x:%04x) -> %d (%s)\n",
			       dd.idVendor, dd.idProduct, orc,
			       orc == 0 ? "OK" : libusb_strerror(orc));
			if (orc == LIBUSB_ERROR_NOT_FOUND) {
				printf("      ^^ NOT_FOUND on a composite device means libusb found NO\n");
				printf("         interface bound to a WinUSB-family driver. composite_open()\n");
				printf("         starts at NOT_FOUND and only succeeds if one opens.\n");
				printf("         Run tools\\adb-usb-check.cmd -- the &MI_01 child needs BOTH\n");
				printf("         Service = WinUSB AND a DeviceInterfaceGUIDs value.\n");
			} else if (orc == LIBUSB_ERROR_ACCESS) {
				printf("      ^^ ACCESS: something else holds the device open (a stray adb server?)\n");
			} else if (orc == 0 && h) {
				replay_attempted = 1;
				if (replay_adb_open(dev, h, &dd) == 0)
					replay_ok = 1;
			}
			if (h)
				libusb_close(h);
		}
	}
	libusb_free_device_list(list, 1);

	printf("\n--- hotplug ---\n");
	rc = libusb_hotplug_register_callback(NULL,
	        LIBUSB_HOTPLUG_EVENT_DEVICE_ARRIVED | LIBUSB_HOTPLUG_EVENT_DEVICE_LEFT,
	        LIBUSB_HOTPLUG_ENUMERATE, LIBUSB_HOTPLUG_MATCH_ANY, LIBUSB_HOTPLUG_MATCH_ANY,
	        LIBUSB_CLASS_PER_INTERFACE, hotplug_cb, &cb_fired, &handle);
	printf("libusb_hotplug_register_callback -> %d (%s)\n",
	       rc, rc == LIBUSB_SUCCESS ? "OK" : libusb_error_name(rc));
	printf("  (this is the exact call adb makes at usb_libusb.cpp:1064;\n");
	printf("   a non-zero rc there is the LOG(FATAL) that kills the adb server)\n");
	if (rc == LIBUSB_SUCCESS) {
		printf("ENUMERATE fired callback for       %d device(s)\n", cb_fired);
		libusb_hotplug_deregister_callback(NULL, handle);
	}

	printf("\n--- verdict ---\n");
	printf("HAS_HOTPLUG        : %s\n", hotplug ? "1  PASS" : "0  FAIL");
	printf("devices enumerated : %d  %s\n", (int)n, n > 0 ? "PASS" : "FAIL");
	printf("hotplug register   : %s\n", rc == LIBUSB_SUCCESS ? "OK  PASS" : "FAILED");
	printf("0E8D device present: %s\n", target_found ? "yes" : "no (phone not attached, or not in an ADB mode)");
	printf("ADB interface FF/42/01 seen: %s\n", adb_iface_found ? "yes" : "no");
	if (replay_attempted)
		printf("adb OpenDevice replay: %s\n",
		       replay_ok ? "PASS -- adb has no USB-level excuse in this mode"
		                 : "FAIL -- see the named call above");
	else
		printf("adb OpenDevice replay: not attempted (no 0E8D device opened)\n");

	libusb_exit(NULL);

	if (!hotplug || n <= 0 || rc != LIBUSB_SUCCESS) {
		printf("\nVERDICT: FAIL -- do not carry this build to the device.\n");
		return 1;
	}
	printf("\nVERDICT: PASS -- libusb has hotplug and enumerates devices.\n");
	if (!target_found)
		printf("         (the phone was not attached; that is a separate question)\n");
	return 0;
}
