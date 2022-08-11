#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_external_texture.h"

#include "vulkan_texture.h"

#include "bss2kdpy.h"

#include <unistd.h>
#include <fcntl.h>

#include <sys/ioctl.h>

#include <bss2k_ioctl.h>

bool vulkan_external_texture_setup(struct global *g)
{
	// get extension function
	PFN_vkGetMemoryFdPropertiesKHR const vkGetMemoryFdPropertiesKHR =
		(PFN_vkGetMemoryFdPropertiesKHR)vkGetDeviceProcAddr(
				g->device,
				"vkGetMemoryFdPropertiesKHR");
	if(!vkGetMemoryFdPropertiesKHR)
		return false;

	// fd representing the DMA buffer for the imported texture
	int mem_fd;

	{
		int bss2k_dev = open("/dev/bss2k-0", O_RDWR);
		if(bss2k_dev == -1)
			return false;

		int rc = ioctl(bss2k_dev, BSS2K_IOC_GET_TEXTMODE_TEXTURE, &mem_fd);
		if(rc == -1)
			return false;
	}

	VkExternalMemoryImageCreateInfo const external_texture_image_info =
	{
		.sType = VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
		.pNext = NULL,
		.handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT
	};

	VkImageCreateInfo const image_info =
	{
		.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
		.pNext = &external_texture_image_info,
		.imageType = VK_IMAGE_TYPE_2D,
		.extent =
		{
			.width = 480,
			.height = 360,
			.depth = 1
		},
		.mipLevels = 1,
		.arrayLayers = 1,
		.format = VK_FORMAT_R8G8B8A8_SRGB,
		.tiling = VK_IMAGE_TILING_LINEAR,
		.initialLayout = VK_IMAGE_LAYOUT_PREINITIALIZED,
		.usage = VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
		.sharingMode = VK_SHARING_MODE_EXCLUSIVE,
		.samples = VK_SAMPLE_COUNT_1_BIT,
		.flags = 0
	};

	VkResult rc = vkCreateImage(
			g->device,
			&image_info,
			g->allocation_callbacks,
			&g->textmode_texture_external.image);
	if(rc != VK_SUCCESS)
		return false;

	uint32_t memory_type_index;

	{
		VkMemoryFdPropertiesKHR prop =
		{
			.sType = VK_STRUCTURE_TYPE_MEMORY_FD_PROPERTIES_KHR,
			.pNext = NULL
		};

		VkResult rc = vkGetMemoryFdPropertiesKHR(
				g->device,
				VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT,
				mem_fd,
				&prop);

		if(rc != VK_SUCCESS)
			return false;

		for(memory_type_index = 0; memory_type_index < 32; ++memory_type_index)
			if(prop.memoryTypeBits & ((uint32_t)1u << memory_type_index))
				break;

		if(memory_type_index == 32)
			return false;
	}

	VkDeviceSize const size = 480 * 360 * 4;

	{
		VkImportMemoryFdInfoKHR const external_texture_info =
		{
			.sType = VK_STRUCTURE_TYPE_IMPORT_MEMORY_FD_INFO_KHR,
			.pNext = NULL,
			.handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT,
			.fd = mem_fd,
		};

		VkMemoryAllocateInfo const info =
		{
			.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
			.pNext = &external_texture_info,
			.allocationSize = size,
			.memoryTypeIndex = memory_type_index
		};

		VkResult rc = vkAllocateMemory(
				g->device,
				&info,
				g->allocation_callbacks,
				&g->textmode_texture_external.memory);
		if(rc != VK_SUCCESS)
			return false;
	}

	return true;
}

void vulkan_external_texture_teardown(struct global *g)
{
	vulkan_texture_destroy(
			g,
			g->textmode_texture_external.image,
			g->textmode_texture_external.memory);
	g->textmode_texture_external.memory = VK_NULL_HANDLE;
	g->textmode_texture_external.image = VK_NULL_HANDLE;
}
