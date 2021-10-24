#import <Foundation/Foundation.h>
#import <MobileWiFi/MobileWiFi.h>
#include <err.h>
#include <stdbool.h>
#include <stdio.h>

#include "wifi.h"

CFArrayRef connectNetworks;
WiFiManagerRef manager;

int wifi(int argc, char *argv[]) {
	if (!argv[2]) {
		errx(1, "no wifi subcommand specified");
		return 1;
	}

	int ret = 1;
	manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
	// WiFiManagerClientGetDevice(WiFiManagerRef) segfaults
	// We should investigate, but this works for now.
	CFArrayRef devices = WiFiManagerClientCopyDevices(manager);
	if (!devices) {
		errx(1, "Failed to get devices");
	}
	WiFiDeviceClientRef client =
		(WiFiDeviceClientRef)CFArrayGetValueAtIndex(devices, 0);

	// TODO: Make this not an ugly blob
	if (!strcmp(argv[2], "current")) {
		ret = info(client, true, argc - 2, argv + 2);
	} else if (!strcmp(argv[2], "info")) {
		ret = info(client, false, argc - 2, argv + 2);
	} else if (!strcmp(argv[2], "list")) {
		ret = list();
	} else if (!strcmp(argv[2], "power")) {
		if (argc != 4)
			ret = power(NULL);
		else if (!strcmp(argv[3], "on") || !strcmp(argv[3], "off") ||
				 !strcmp(argv[3], "toggle") || !strcmp(argv[3], "status"))
			ret = power(argv[3]);
		else
			errx(1, "invalid action");
	} else if (!strcmp(argv[2], "scan"))
		ret = scan(client);
	else if (!strcmp(argv[2], "connect"))
		ret = connect(client, argc - 2, argv + 2);
	else if (!strcmp(argv[2], "disconnect"))
		ret = WiFiDeviceClientDisassociate(client);
	else
		errx(1, "invalid wifi subcommand");
	CFRelease(manager);
	return ret;
}

int list() {
	CFArrayRef networks = WiFiManagerClientCopyNetworks(manager);

	for (int i = 0; i < CFArrayGetCount(networks); i++) {
		printf("%s : %s\n",
			[(NSString *)CFBridgingRelease(WiFiNetworkGetSSID(
				(WiFiNetworkRef)CFArrayGetValueAtIndex(networks, i)))
				UTF8String],
			networkBSSID((WiFiNetworkRef)CFArrayGetValueAtIndex(networks, i)));
	}

	return 0;
}

const char *networkBSSID(WiFiNetworkRef network) {
	return [(NSString *)CFBridgingRelease(networkBSSIDRef(network)) UTF8String];
}

CFStringRef networkBSSIDRef(WiFiNetworkRef network) {
	return WiFiNetworkGetProperty(network, CFSTR("BSSID"));
}

int info(WiFiDeviceClientRef client, bool current, int argc, char **argv) {
	WiFiNetworkRef network;
	int ch;
	bool bssid = false;
	char *key = NULL;

	while ((ch = getopt(argc, argv, "bk:s")) != -1) {
		switch (ch) {
			case 'b':
				bssid = true;
				break;
			case 'k':
				key = optarg;
				break;
			case 's':
				bssid = false;
				break;
		}
	}
	argc -= optind;
	argv += optind;

	if (!current && argv[0] == NULL)
		errx(1, "no SSID or BSSID specified");

	if (current)
		network = WiFiDeviceClientCopyCurrentNetwork(client);
	else if (bssid)
		network = getNetworkWithBSSID(argv[0]);
	else
		network = getNetworkWithSSID(argv[0]);

	if (key != NULL) {
		CFPropertyListRef property = WiFiNetworkGetProperty(
			network, (__bridge CFStringRef)[NSString stringWithUTF8String:key]);
		if (!property) errx(1, "cannot get property \"%s\"", key);

		CFTypeID type = CFGetTypeID(property);

		if (type == CFStringGetTypeID()) {
			printf("%s: %s\n", key,
				[(NSString *)CFBridgingRelease(WiFiNetworkGetProperty(
					network,
					(__bridge CFStringRef)[NSString stringWithUTF8String:key]))
					UTF8String]);
		} else if (type == CFNumberGetTypeID()) {
			printf("%s: %i\n", key,
				[(NSNumber *)CFBridgingRelease(WiFiNetworkGetProperty(
					network,
					(__bridge CFStringRef)[NSString stringWithUTF8String:key]))
					intValue]);
		} else if (type == CFDateGetTypeID()) {
			printf("%s: %s\n", key,
				[(NSDate *)CFBridgingRelease(WiFiNetworkGetProperty(
					 network,
					 (__bridge CFStringRef)[NSString stringWithUTF8String:key]))
					description]
					.UTF8String);
		} else if (type == CFBooleanGetTypeID()) {
			printf("%s: %s\n", key,
				CFBooleanGetValue(WiFiNetworkGetProperty(
					network,
					(__bridge CFStringRef)[NSString stringWithUTF8String:key]))
					? "true"
					: "false");
		} else
			errx(1, "unknown return type");
		return 0;
	}

	printf("SSID: %s\n", [(NSString *)CFBridgingRelease(
							 WiFiNetworkGetSSID(network)) UTF8String]);
	printf("BSSID: %s\n", networkBSSID(network));
	printf("WEP: %s\n", WiFiNetworkIsWEP(network) ? "yes" : "no");
	printf("WPA: %s\n", WiFiNetworkIsWPA(network) ? "yes" : "no");
	printf("EAP: %s\n", WiFiNetworkIsEAP(network) ? "yes" : "no");
	printf("Apple Hotspot: %s\n",
		   WiFiNetworkIsApplePersonalHotspot(network) ? "yes" : "no");
	printf("Adhoc: %s\n", WiFiNetworkIsAdHoc(network) ? "yes" : "no");
	printf("Hidden: %s\n", WiFiNetworkIsHidden(network) ? "yes" : "no");
	printf("Password Required: %s\n",
		   WiFiNetworkRequiresPassword(network) ? "yes" : "no");
	printf("Username Required: %s\n",
		   WiFiNetworkRequiresUsername(network) ? "yes" : "no");

	if (current) {
		CFDictionaryRef data = (CFDictionaryRef)WiFiDeviceClientCopyProperty(
			client, CFSTR("RSSI"));
		CFNumberRef scaled = (CFNumberRef)WiFiDeviceClientCopyProperty(
			client, kWiFiScaledRSSIKey);

		CFNumberRef RSSI =
			(CFNumberRef)CFDictionaryGetValue(data, CFSTR("RSSI_CTL_AGR"));
		CFRelease(data);

		int raw;
		CFNumberGetValue(RSSI, kCFNumberIntType, &raw);

		float strength;
		CFNumberGetValue(scaled, kCFNumberFloatType, &strength);
		CFRelease(scaled);

		strength *= -1;

		// Apple uses -3.0.
		int bars = (int)ceilf(strength * -3.0f);
		bars = MAX(1, MIN(bars, 3));

		printf("Strength: %f dBm\n", strength);
		printf("Bars: %d\n", bars);
		printf("Channel: %i\n",
			   [(NSNumber *)CFBridgingRelease(WiFiNetworkGetProperty(
				   network, CFSTR("CHANNEL"))) intValue]);
		printf("AP Mode: %i\n",
			   [(NSNumber *)CFBridgingRelease(WiFiNetworkGetProperty(
				   network, CFSTR("AP_MODE"))) intValue]);
		printf("Interface: %s\n",
			   [(NSString *)CFBridgingRelease(
				   WiFiDeviceClientGetInterfaceName(client)) UTF8String]);
	}
	return 0;
}

WiFiNetworkRef getNetworkWithSSID(char *ssid) {
	WiFiNetworkRef network;
	CFArrayRef networks = WiFiManagerClientCopyNetworks(manager);

	for (int i = 0; i < CFArrayGetCount(networks); i++) {
		if (CFEqual(CFStringCreateWithCString(kCFAllocatorDefault, ssid, kCFStringEncodingUTF8),
					WiFiNetworkGetSSID((WiFiNetworkRef)CFArrayGetValueAtIndex(networks, i)))) {
			network = (WiFiNetworkRef)CFArrayGetValueAtIndex(networks, i);
			break;
		}
	}

	if (network == NULL)
		errx(1, "Could not find network with specified SSID: %s", ssid);

	return network;
}

WiFiNetworkRef getNetworkWithBSSID(char *ssid) {
	WiFiNetworkRef network;
	CFArrayRef networks = WiFiManagerClientCopyNetworks(manager);

	for (int i = 0; i < CFArrayGetCount(networks); i++) {
		if (CFEqual(CFStringCreateWithCString(kCFAllocatorDefault, ssid, kCFStringEncodingUTF8),
					networkBSSIDRef((WiFiNetworkRef)CFArrayGetValueAtIndex(networks, i)))) {
			network = (WiFiNetworkRef)CFArrayGetValueAtIndex(networks, i);
			break;
		}
	}

	if (network == NULL)
		errx(1, "Could not find network with specified SSID: %s", ssid);

	return network;
}
