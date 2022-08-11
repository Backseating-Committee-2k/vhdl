#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_descriptor_pool.h"

#include "bss2kdpy.h"

bool vulkan_descriptor_pool_setup(struct global *g)
{
	uint32_t const max_frames_in_flight = 1;

	VkDescriptorPoolSize const descriptor_pool_sizes[] =
	{
		{
			.type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
			.descriptorCount = max_frames_in_flight
		}
	};

	VkDescriptorPoolCreateInfo const descriptor_pool_info =
	{
		.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
		.poolSizeCount = sizeof descriptor_pool_sizes /
				sizeof descriptor_pool_sizes[0],
		.pPoolSizes = descriptor_pool_sizes,
		.maxSets = max_frames_in_flight
	};

	VkResult rc = vkCreateDescriptorPool(
			g->device,
			&descriptor_pool_info,
			g->allocation_callbacks,
			&g->descriptor_pool);
	if(rc != VK_SUCCESS)
		return false;

	return true;
}

void vulkan_descriptor_pool_teardown(struct global *g)
{
	if(g->descriptor_pool != VK_NULL_HANDLE)
	{
		vkDestroyDescriptorPool(
				g->device,
				g->descriptor_pool,
				g->allocation_callbacks);
		g->descriptor_pool = VK_NULL_HANDLE;
	}
}
