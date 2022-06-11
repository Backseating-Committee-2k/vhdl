#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_vulkan.h"
#include "x11_setup.h"
#include "x11_mainloop.h"
#include "vulkan_instance.h"
#include "vulkan_device.h"
#include "vulkan_swapchain.h"

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
		goto fail_x11;

	if(!vulkan_instance_setup(&g))
		goto fail_vulkan_instance;

	if(!x11_vulkan_setup(&g))
		goto fail_x11_vulkan;

	if(!vulkan_device_setup(&g))
		goto fail_vulkan_device;

	if(!x11_mainloop(&g))
		goto fail_x11_mainloop;

	// success starts here
	rc = 0;

fail_x11_mainloop:
	/* shouldn't be necessary */
	vulkan_swapchain_teardown(&g);

	vulkan_device_teardown(&g);

fail_vulkan_device:
	x11_vulkan_teardown(&g);

fail_x11_vulkan:
	vulkan_instance_teardown(&g);

fail_vulkan_instance:
	x11_teardown(&g);

fail_x11:
	return rc;
}
