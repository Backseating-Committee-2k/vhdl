#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_swapchain.h"

#include "bss2kdpy.h"

#include "util.h"

#include <vulkan/vulkan.h>


bool vulkan_swapchain_update(struct global *g)
{
	uint32_t const minImageCount = g->surface_capabilities.minImageCount;
	uint32_t const maxImageCount = g->surface_capabilities.maxImageCount;

	uint32_t const imageCount =
			(maxImageCount == 0)
			? (minImageCount + 1)
			: (min(minImageCount + 1, maxImageCount));

	VkExtent2D const minExtent = g->surface_capabilities.minImageExtent;
	VkExtent2D const maxExtent = g->surface_capabilities.maxImageExtent;

	/** @todo replace image sharing by ownership transfer */
	bool const image_sharing_needed =
			g->graphics_queue_family_index !=
				g->present_queue_family_index;

	uint32_t const queue_family_indices[2] =
	{
		g->graphics_queue_family_index,
		g->present_queue_family_index
	};

	/* if queue families are the same, we use exclusive mode, so we
	 * don't need to pass any family indices which should be enabled
	 * for sharing
	 */
	uint32_t const used_indices_count =
			image_sharing_needed
			? 2
			: 0;
	VkSharingMode const sharing_mode =
			image_sharing_needed
			? VK_SHARING_MODE_CONCURRENT
			: VK_SHARING_MODE_EXCLUSIVE;

	VkSwapchainCreateInfoKHR const info =
	{
		.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
		.surface = g->surface,
		.minImageCount = imageCount,
		.imageFormat = g->surface_format.format,
		.imageColorSpace = g->surface_format.colorSpace,
		.imageExtent =
		{
			.width = clamp(
					g->canvas.w,
					minExtent.width,
					maxExtent.width),
			.height = clamp(
					g->canvas.h,
					minExtent.height,
					maxExtent.height)
		},
		.imageArrayLayers = 1,
		.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
		.imageSharingMode = sharing_mode,
		.queueFamilyIndexCount = used_indices_count,
		.pQueueFamilyIndices = queue_family_indices,
		.preTransform = g->surface_capabilities.currentTransform,
		.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		.presentMode = g->present_mode,
		.clipped = VK_TRUE,
		.oldSwapchain = g->swapchain
	};

	VkResult rc = vkCreateSwapchainKHR(
			g->device,
			&info,
			g->allocation_callbacks,
			&g->swapchain);
	if(rc != VK_SUCCESS)
		goto fail_create_swapchain;

	return true;

fail_create_swapchain:
	return false;
}

void vulkan_swapchain_teardown(struct global *g)
{
	if(g->swapchain != VK_NULL_HANDLE)
	{
		vkDestroySwapchainKHR(
				g->device,
				g->swapchain,
				g->allocation_callbacks);
		g->swapchain = VK_NULL_HANDLE;
	}
}
