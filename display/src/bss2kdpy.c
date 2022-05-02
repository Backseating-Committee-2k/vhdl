#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_setup.h"
#include "x11_mainloop.h"
#include "vulkan_setup.h"

#include "bss2kdpy.h"

#include <unistd.h>

int main(int argc, char **argv)
{
	int rc = 1;

	struct global g =
	{
		.argc = argc,
		.argv = argv
	};

	if(!x11_setup(&g))
		goto fail;

	if(!vulkan_setup(&g))
		goto fail_x11;

	if(!x11_mainloop(&g))
		goto fail_vulkan;

	// success starts here
	rc = 0;

fail_vulkan:
	vulkan_teardown(&g);

fail_x11:
	x11_teardown(&g);

fail:
	return rc;
}
