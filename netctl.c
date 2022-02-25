#include <err.h>
#include <stdio.h>
#include <string.h>

int wifi(int, char **);
int cellular(int, char **);
int airdrop(int, char **);
int nctl_monitor(int, char **);
int nctl_print(int, char **);
int airplane(char *);

void usage(void);

int main(int argc, char *argv[]) {
	if (argc < 2) {
		usage();
		return 1;
	}

#if NO_WIFI == 0
	if (!strcmp(argv[1], "wifi")) return wifi(argc, argv);
#endif

#if NO_CELLULAR == 0
	if (!strcmp(argv[1], "cellular")) return cellular(argc, argv);
#endif

#if NO_AIRDROP == 0
	if (!strcmp(argv[1], "airdrop")) return airdrop(argc, argv);
#endif

#if NO_AIRPLANE == 0
	if (!strcmp(argv[1], "airplane"))
		return airplane(argc > 2 ? argv[2] : NULL);
#endif

#if NO_MONITOR == 0
	if (!strcmp(argv[1], "monitor")) return nctl_monitor(argc - 2, argv + 2);
#endif

#if NO_PRINT == 0
	if (!strcmp(argv[1], "print")) return nctl_print(argc - 2, argv + 2);
#endif

	usage();
	return 1;
}

void usage() {
	fprintf(stderr,
			"Usage: netctl [airdrop | cellular | wifi | monitor | print] "
			"[arguments]\n");
}
