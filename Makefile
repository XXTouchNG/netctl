CC    := xcrun -sdk iphoneos cc -arch arm64
STRIP := xcrun -sdk iphoneos strip

LDID  := ldid

NO_CELLULAR ?= 0
NO_WIFI     ?= 0
NO_AIRDROP  ?= 0
NO_AIRPLANE ?= 0
NO_PRINT    ?= 0
NO_MONITOR  ?= 0

ifeq ($(BUILD_FOR_MACOSX),1)
NO_CELLULAR = 1
NO_WIFI = 1
NO_AIRPLANE = 1
endif

CFLAGS += -DNO_CELLULAR=$(NO_CELLULAR) -DNO_WIFI=$(NO_WIFI) -DNO_AIRDROP=$(NO_AIRDROP) -DNO_AIRPLANE=$(NO_AIRPLANE) -DNO_PRINT=$(NO_PRINT) -DNO_MONITOR=$(NO_MONITOR)

SRC := netctl.c
SRC += utils/output.m utils/strtonum.c
ifneq ($(NO_CELLULAR),1)
SRC += cellular/cellular.m
LIBS += -framework CoreTelephony
endif
ifneq ($(NO_WIFI),1)
SRC += wifi/wifi.m wifi/wifi-connect.m wifi/wifi-scan.m wifi/wifi-power.m wifi/wifi-info.m wifi/wifi-forget.m
LIBS += -framework MobileWiFi
endif
ifneq ($(NO_AIRDROP),1)
SRC += airdrop/airdrop.c airdrop/airdrop-scan.m airdrop/airdrop-send.m airdrop/airdrop-power.m
LIBS += -framework Sharing
endif
ifneq ($(NO_AIRPLANE),1)
SRC += airplane/airplane.m
LIBS += -framework AppSupport
endif
ifneq ($(NO_MONITOR),1)
SRC += monitor/monitor.m monitor/SourceInfo.m monitor/DataInfo.m
LIBS += -framework NetworkStatistics
endif
ifneq ($(NO_PRINT),1)
SRC += print/print.m
LIBS += -lcups
endif

all: netctl

%.m.o: %.m
	$(CC) $(CFLAGS) -Iinclude -F Frameworks -fobjc-arc $< -c -o $@

%.c.o: %.c
	$(CC) $(CFLAGS) $< -c -o $@

netctl: $(SRC:%=%.o)
	$(CC) $(CFLAGS) $(LDFLAGS) -F Frameworks -fobjc-arc $^ -o $@ $(LIBS)
	$(STRIP) $@
	-$(LDID) -Cadhoc -Sentitlements.plist $@

clean:
	rm -rf netctl *.dSYM $(SRC:%=%.o)

format:
	clang-format -i $(SRC)

.PHONY: all clean format
