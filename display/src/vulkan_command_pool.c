#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_command_pool.h"

#include "bss2kdpy.h"

bool vulkan_command_pool_setup(struct global *g)
{
	VkCommandPoolCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
		.queueFamilyIndex = g->queue.graphics.family_index
	};

	VkResult rc = vkCreateCommandPool(
			g->device,
			&info,
			g->allocation_callbacks,
			&g->graphics_command_pool);
	if(rc != VK_SUCCESS)
		goto fail_command_pool;

	return true;

fail_command_pool:
	return false;
}

void vulkan_command_pool_teardown(struct global *g)
{
	if(g->graphics_command_pool != VK_NULL_HANDLE)
	{
		vkDestroyCommandPool(
				g->device,
				g->graphics_command_pool,
				g->allocation_callbacks);
		g->graphics_command_pool = VK_NULL_HANDLE;
	}
}
