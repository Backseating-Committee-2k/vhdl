#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "device.h"

#include "bss2kdpy.h"

#include <fcntl.h>
#include <unistd.h>

bool device_setup(struct global *g)
{
	g->bss2k_device = open("/dev/bss2k-0", O_RDWR);
	if(g->bss2k_device == -1)
		return false;
	return true;
}

void device_teardown(struct global *g)
{
	if(g->bss2k_device != -1)
	{
		close(g->bss2k_device);
		g->bss2k_device = -1;
	}
}
