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

	return true;
}

void vulkan_external_texture_teardown(struct global *g)
{
	vulkan_texture_destroy(
			g,
			g->textmode_texture_external.image,
			NULL);
	g->textmode_texture_external.image = VK_NULL_HANDLE;
}
