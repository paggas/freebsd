/* Paggas 170627 */

#include <sys/types.h>
#include <net/if.h>
#include <net/pfvar.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <err.h>
#include <fcntl.h>
#include <stdio.h>

int
pfctl_test_altqsupport(int dev)
{
	struct pfioc_altq pa;

	if (ioctl(dev, DIOCGETALTQS, &pa)) {
		if (errno == ENODEV) {
			return (0);
		} else
			err(1, "DIOCGETALTQS");
	}
	return (1);
}

int
main(int argc, char *argv[])
{
	int dev;
	int altqsupport;
	if ((dev = open("/dev/pf", O_RDONLY)) == -1)
		err(1, "/dev/pf");
	if ((altqsupport = pfctl_test_altqsupport(dev))) {
		printf("ALTQ support present in kernel.\n");
		return (0);
	} else {
		printf("No ALTQ support in kernel.\n");
		return (1);
	}
}
