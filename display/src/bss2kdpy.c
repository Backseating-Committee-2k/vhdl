#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_setup.h"

#include "bss2kdpy.h"

int main(int argc, char **argv)
{
	int rc = 1;

	struct global g;

	(void)argc;
	(void)argv;

	if(!vulkan_setup(&g))
		goto fail;

	// success starts here
	rc = 0;

	vulkan_teardown(&g);

fail:
	return rc;
}
