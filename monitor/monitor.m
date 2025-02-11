#import <Foundation/Foundation.h>
#import <NetworkStatistics/NetworkStatistics.h>
#import <arpa/inet.h>
#import <err.h>
#import <netdb.h>
#import <sys/socket.h>

#import "SourceInfo.h"

void (^description_block)(CFDictionaryRef) = ^(CFDictionaryRef cfDict) {
  NSDictionary* dict = (__bridge NSDictionary*)cfDict;
  NCSourceInfo* info = [[NCSourceInfo alloc] initWithDict:dict];

  char localHostname[256] = {0};
  getnameinfo(info.localAddress, info.localAddress->sa_len, localHostname,
			  sizeof(localHostname), NULL, 0, NI_NUMERICHOST);

  char remoteHostname[256] = {0};
  getnameinfo(info.remoteAddress, info.remoteAddress->sa_len, remoteHostname,
			  sizeof(remoteHostname), NULL, 0, NI_NUMERICHOST);

  NSString* protocolString = info.protocol;
  if (info.TCPState) {
	  protocolString = [protocolString
		  stringByAppendingString:[NSString
									  stringWithFormat:@"(%@)", info.TCPState]];
  }

  printf("%s\t%20s%30s\t%30s\ttx:%llu rx:%llu\t %s(%d)\n",
		 info.timeStamp.UTF8String, protocolString.UTF8String, localHostname,
		 remoteHostname, info.dataProcessed.tx.unsignedLongLongValue,
		 info.dataProcessed.rx.unsignedLongLongValue,
		 info.processName.UTF8String, info.PID.intValue);
};

void (^callback)(void*, void*) = ^(NStatSourceRef ref, void* arg2) {
  NStatSourceSetDescriptionBlock(ref, description_block);
  NStatSourceQueryDescription(ref);
};

int nctl_monitor(int argc, char** argv) {
	if (argc < 1) {
		errno = EINVAL;
		errx(1, "not enough args");
	}

	BOOL monitorTCP = NO;
	BOOL monitorUDP = NO;

	if (!strcmp(argv[0], "tcp")) {
		monitorTCP = YES;
	}
	if (!strcmp(argv[0], "udp")) {
		monitorUDP = YES;
	}
	if (!strcmp(argv[0], "all")) {
		monitorTCP = YES;
		monitorUDP = YES;
	}

	NStatManagerRef ref = NStatManagerCreate(
		kCFAllocatorDefault, dispatch_get_main_queue(), callback);

	if (monitorTCP) {
		NStatManagerAddAllTCPWithFilter(ref, 0, 0);
	}

	if (monitorUDP) {
		NStatManagerAddAllUDPWithFilter(ref, 0, 0);
	}

	NStatManagerSetFlags(ref, 0);

	NStatManagerAddAllTCPWithFilter(ref, 0, 0);

	dispatch_main();
}
