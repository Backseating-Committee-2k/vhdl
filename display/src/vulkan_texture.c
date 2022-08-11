#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_texture.h"

#include "bss2kdpy.h"

bool vulkan_texture_create(
		struct global *g,
		uint32_t width,
		uint32_t height,
		VkImage *out_image,
		VkDeviceMemory *out_memory)
{
	VkImage image;
	VkDeviceMemory memory;

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
				&image);
		if(rc != VK_SUCCESS)
			goto fail_createimage;
	}

	VkDeviceSize memory_size;
	uint32_t memory_type_index;

	{
		VkMemoryRequirements requirements;

		vkGetImageMemoryRequirements(
				g->device,
				image,
				&requirements);

		uint32_t const allowed_for_image =
			requirements.memoryTypeBits;

		uint32_t const device_local_allowed_for_image =
			allowed_for_image & g->device_local_memory_types;

		/* works if there is overlap in bit masks */
		bool const can_use_device_local_memory =
			!!(device_local_allowed_for_image);

		/* prefer device local memory, fall back otherwise */
		uint32_t const filter =
			can_use_device_local_memory
			? device_local_allowed_for_image
			: allowed_for_image;

		uint32_t i;

		for(i = 0; i < VK_MAX_MEMORY_TYPES; ++i)
		{
			uint32_t const bit = ((uint32_t)1u) << i;

			if(filter & bit)
				break;
		}

		if(i == 32)
			return false;

		memory_size = requirements.size;
		memory_type_index = i;
	}

	{
		VkMemoryAllocateInfo const info =
		{
			.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
			.pNext = NULL,
			.allocationSize = memory_size,
			.memoryTypeIndex = memory_type_index
		};

		VkResult rc = vkAllocateMemory(
				g->device,
				&info,
				g->allocation_callbacks,
				&memory);
		if(rc != VK_SUCCESS)
			goto fail_allocatememory;
	}

	VkResult rc = vkBindImageMemory(
			g->device,
			image,
			memory,
			/* offset */ 0);
	if(rc != VK_SUCCESS)
		goto fail_bindimagememory;

	*out_image = image;
	*out_memory = memory;

	return true;

fail_bindimagememory:
	vkFreeMemory(
			g->device,
			memory,
			g->allocation_callbacks);

fail_allocatememory:
	vkDestroyImage(
			g->device,
			image,
			g->allocation_callbacks);

fail_createimage:
	return false;
}

void vulkan_texture_destroy(
		struct global *g,
		VkImage image,
		VkDeviceMemory memory)
{
	if(memory != VK_NULL_HANDLE)
	{
		vkFreeMemory(
				g->device,
				memory,
				g->allocation_callbacks);
	}

	{
	if(image != VK_NULL_HANDLE)
		vkDestroyImage(
				g->device,
				image,
				g->allocation_callbacks);
	}
}

bool vulkan_texture_setup(struct global *g)
{
	return vulkan_texture_create(
			g,
			SCREEN_WIDTH,
			SCREEN_HEIGHT,
			&g->textmode_texture_internal.image,
			&g->textmode_texture_internal.memory);
}

void vulkan_texture_teardown(struct global *g)
{
	vulkan_texture_destroy(
			g,
			g->textmode_texture_internal.image,
			g->textmode_texture_internal.memory);

	g->textmode_texture_internal.memory = VK_NULL_HANDLE;
	g->textmode_texture_internal.image = VK_NULL_HANDLE;
}
