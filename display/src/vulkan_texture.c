#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_texture.h"

#include "bss2kdpy.h"

bool vulkan_texture_setup(struct global *g)
{
	uint32_t const width = SCREEN_WIDTH;
	uint32_t const height = SCREEN_HEIGHT;

	{
		VkImageCreateInfo const info =
		{
			.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
			.pNext = NULL,
			.imageType = VK_IMAGE_TYPE_2D,
			.extent =
			{
				.width = width,
				.height = height,
				.depth = 1
			},
			.mipLevels = 1,
			.arrayLayers = 1,
			.format = VK_FORMAT_R8G8B8A8_SRGB,
			.tiling = VK_IMAGE_TILING_OPTIMAL,
			.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
			.usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT |
				VK_IMAGE_USAGE_SAMPLED_BIT,
			.sharingMode = VK_SHARING_MODE_EXCLUSIVE,
			.samples = VK_SAMPLE_COUNT_1_BIT,
			.flags = 0
		};

		VkResult rc = vkCreateImage(
				g->device,
				&info,
				g->allocation_callbacks,
				&g->textmode_texture_internal.image);
		if(rc != VK_SUCCESS)
			goto fail_createimage;
	}

	return true;

fail_createimage:
	return false;
}

void vulkan_texture_teardown(struct global *g)
{
	if(g->textmode_texture_internal.image != VK_NULL_HANDLE)
	{
		vkDestroyImage(
				g->device,
				g->textmode_texture_internal.image,
				g->allocation_callbacks);
		g->textmode_texture_internal.image = VK_NULL_HANDLE;
	}
}
