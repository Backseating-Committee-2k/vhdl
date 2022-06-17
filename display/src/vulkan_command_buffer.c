#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_command_buffer.h"

#include "bss2kdpy.h"

bool vulkan_command_buffer_setup(struct global *g)
{
	uint32_t const command_buffer_count =
			sizeof g->graphics_command_buffers /
				sizeof g->graphics_command_buffers[0];

	VkCommandBufferAllocateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = g->graphics_command_pool,
		.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		.commandBufferCount = command_buffer_count
	};

	VkResult rc = vkAllocateCommandBuffers(
			g->device,
			&info,
			g->graphics_command_buffers);
	if(rc != VK_SUCCESS)
		goto fail_command_buffers;

	return true;

fail_command_buffers:
	return false;
}

void vulkan_command_buffer_teardown(struct global *g)
{
	uint32_t const command_buffer_count =
			sizeof g->graphics_command_buffers /
				sizeof g->graphics_command_buffers[0];

	vkFreeCommandBuffers(
			g->device,
			g->graphics_command_pool,
			command_buffer_count,
			g->graphics_command_buffers);
}
