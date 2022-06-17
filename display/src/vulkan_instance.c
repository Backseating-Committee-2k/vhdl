#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_instance.h"

#include "bss2kdpy.h"

bool vulkan_instance_setup(struct global *g)
{
	/* if you want a custom allocator, here is where you set it up. */
	g->allocation_callbacks = NULL;

	/* initialize */
	g->instance = VK_NULL_HANDLE;
	g->surface = VK_NULL_HANDLE;
	g->physical_device = VK_NULL_HANDLE;
	g->device = VK_NULL_HANDLE;
	g->sem.image_available = VK_NULL_HANDLE;
	g->sem.render_finished = VK_NULL_HANDLE;
	g->swapchain = VK_NULL_HANDLE;
	g->render_pass = VK_NULL_HANDLE;
	g->pipeline_layout = VK_NULL_HANDLE;
	g->pipelines[0] = VK_NULL_HANDLE;
	g->graphics_command_pool = VK_NULL_HANDLE;
	g->shaders.frag = VK_NULL_HANDLE;
	g->shaders.vert = VK_NULL_HANDLE;
	g->swapchain_image_count = 0;
	g->swapchain_images = NULL;

	VkApplicationInfo const app_info =
	{
		.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
		.pNext = NULL,
		.pApplicationName = "BackseatSafeSystem2k Display",
		.applicationVersion = 0,
		.pEngineName = "No Engine",
		.engineVersion = 0,
		.apiVersion = VK_API_VERSION_1_2
	};

	char const *const layers[] =
	{
#ifndef NDEBUG
		"VK_LAYER_KHRONOS_validation"
#endif
	};

	char const *const extensions[] =
	{
		"VK_KHR_surface",
		"VK_KHR_xlib_surface"
	};

	VkInstanceCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		.pNext = NULL,
		.flags = 0,
		.pApplicationInfo = &app_info,
		.enabledLayerCount = sizeof layers / sizeof *layers,
		.ppEnabledLayerNames = layers,
		.enabledExtensionCount = sizeof extensions / sizeof *extensions,
		.ppEnabledExtensionNames = extensions
	};

	VkResult rc = vkCreateInstance(
			&info,
			g->allocation_callbacks,
			&g->instance);

	if(rc != VK_SUCCESS)
		goto fail;

	return true;

fail:
	vulkan_instance_teardown(g);
	return false;
}

void vulkan_instance_teardown(struct global *g)
{
	if(g->instance != VK_NULL_HANDLE)
		vkDestroyInstance(
				g->instance,
				g->allocation_callbacks);
	g->instance = NULL;
}
