#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_vulkan.h"

#include "bss2kdpy.h"

#include <vulkan/vulkan_xlib.h>

bool x11_vulkan_setup(struct global *g)
{
	VkXlibSurfaceCreateInfoKHR const info =
	{
		.sType = VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
		.pNext = NULL,
		.flags = 0,
		.dpy = g->x11.display,
		.window = g->x11.window
	};

	VkResult rc = vkCreateXlibSurfaceKHR(
			g->instance,
			&info,
			g->allocation_callbacks,
			&g->surface);

	if(rc != VK_SUCCESS)
		return false;

	return true;
}

void x11_vulkan_teardown(struct global *g)
{
	if(g->surface != VK_NULL_HANDLE)
	{
		vkDestroySurfaceKHR(
				g->instance,
				g->surface,
				g->allocation_callbacks);
		g->surface = VK_NULL_HANDLE;
	}
}
