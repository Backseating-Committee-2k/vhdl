#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_swapchain.h"

#include "bss2kdpy.h"

#include "util.h"

#include <vulkan/vulkan.h>

#include <stdlib.h>

#include <assert.h>

static void teardown_image_views(struct global *g)
{
	for(uint32_t i = 0; i < g->swapchain_image_count; ++i)
	{
		if(g->swapchain_images[i].image_view == VK_NULL_HANDLE)
			continue;
		vkDestroyImageView(
				g->device,
				g->swapchain_images[i].image_view,
				g->allocation_callbacks);
		g->swapchain_images[i].image_view = VK_NULL_HANDLE;
	}
}

bool vulkan_swapchain_update(struct global *g)
{
	/* TODO: hardcoded here */
	uint32_t const layer_count = 1;

	teardown_image_views(g);

	for(uint32_t i = 0; i < g->swapchain_image_count; ++i)
		assert(g->swapchain_images[i].image_view == VK_NULL_HANDLE);

	VkSurfaceCapabilitiesKHR surface_capabilities;

	vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
			g->physical_device,
			g->surface,
			&surface_capabilities);

	uint32_t const minImageCount = surface_capabilities.minImageCount;
	uint32_t const maxImageCount = surface_capabilities.maxImageCount;

	uint32_t const imageCount =
			(maxImageCount == 0)
			? (minImageCount + 1)
			: (min(minImageCount + 1, maxImageCount));

	VkExtent2D const minExtent = surface_capabilities.minImageExtent;
	VkExtent2D const maxExtent = surface_capabilities.maxImageExtent;

	/** @todo replace image sharing by ownership transfer */
	bool const image_sharing_needed =
			g->queue.graphics.family_index !=
				g->queue.present.family_index;

	uint32_t const queue_family_indices[2] =
	{
		g->queue.graphics.family_index,
		g->queue.present.family_index
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
		.imageArrayLayers = layer_count,
		.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
		.imageSharingMode = sharing_mode,
		.queueFamilyIndexCount = used_indices_count,
		.pQueueFamilyIndices = queue_family_indices,
		.preTransform = surface_capabilities.currentTransform,
		.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		.presentMode = g->present_mode,
		.clipped = VK_TRUE,
		.oldSwapchain = g->swapchain
	};

	for(uint32_t i = 0; i < g->swapchain_image_count; ++i)
		g->swapchain_images[i].image = VK_NULL_HANDLE;

	VkResult rc = vkCreateSwapchainKHR(
			g->device,
			&info,
			g->allocation_callbacks,
			&g->swapchain);
	if(rc != VK_SUCCESS)
		goto fail_create_swapchain;

	{
		uint32_t swapchain_image_count = 0;

		rc = vkGetSwapchainImagesKHR(
				g->device,
				g->swapchain,
				&swapchain_image_count,
				NULL);
		if(rc != VK_SUCCESS)
			goto fail_get_swapchain_images;

		VkImage swapchain_images[swapchain_image_count];

		rc = vkGetSwapchainImagesKHR(
				g->device,
				g->swapchain,
				&swapchain_image_count,
				swapchain_images);
		if(rc != VK_SUCCESS)
			goto fail_get_swapchain_images;

		if(swapchain_image_count != g->swapchain_image_count)
		{
			if(g->swapchain_images)
				free(g->swapchain_images);

			g->swapchain_images = malloc(swapchain_image_count *
					sizeof g->swapchain_images[0]);
			if(!g->swapchain_images)
				goto fail_get_swapchain_images;
			g->swapchain_image_count = swapchain_image_count;
		}

		for(uint32_t i = 0; i < swapchain_image_count; ++i)
		{
			g->swapchain_images[i].image =
					swapchain_images[i];
			g->swapchain_images[i].image_view =
					VK_NULL_HANDLE;
		}
	}

	for(uint32_t i = 0; i < g->swapchain_image_count; ++i)
		assert(g->swapchain_images[i].image_view == VK_NULL_HANDLE);

	for(uint32_t i = 0; i < g->swapchain_image_count; ++i)
	{
		VkImageViewCreateInfo const info =
		{
			.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
			.image = g->swapchain_images[i].image,
			.viewType = VK_IMAGE_VIEW_TYPE_2D,
			.format = g->surface_format.format,
			.components =
			{
				.r = VK_COMPONENT_SWIZZLE_IDENTITY,
				.g = VK_COMPONENT_SWIZZLE_IDENTITY,
				.b = VK_COMPONENT_SWIZZLE_IDENTITY,
				.a = VK_COMPONENT_SWIZZLE_IDENTITY
			},
			.subresourceRange =
			{
				.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
				.baseMipLevel = 0,
				.levelCount = 1,
				.baseArrayLayer = 0,
				.layerCount = layer_count
			}
		};

		rc = vkCreateImageView(
				g->device,
				&info,
				g->allocation_callbacks,
				&g->swapchain_images[i].image_view);
		if(rc != VK_SUCCESS)
			goto fail_create_image_view;
	}

	return true;

fail_create_image_view:
	/* handled by normal teardown */

fail_get_swapchain_images:
	vulkan_swapchain_teardown(g);

fail_create_swapchain:
	return false;
}

void vulkan_swapchain_teardown(struct global *g)
{
	teardown_image_views(g);

	for(uint32_t i = 0; i < g->swapchain_image_count; ++i)
		g->swapchain_images[i].image = VK_NULL_HANDLE;

	if(g->swapchain_images)
	{
		free(g->swapchain_images);
		g->swapchain_images = NULL;
		g->swapchain_image_count = 0;
	}

	if(g->swapchain != VK_NULL_HANDLE)
	{
		vkDestroySwapchainKHR(
				g->device,
				g->swapchain,
				g->allocation_callbacks);
		g->swapchain = VK_NULL_HANDLE;
	}
}
