#pragma once

#include <X11/Xlib.h>

#include <vulkan/vulkan.h>

#include <stdbool.h>

struct global
{
	int argc;
	char **argv;

	union
	{
		struct
		{
			Display *display;
			Window window;
		} x11;
	};

	VkAllocationCallbacks *allocation_callbacks;

	VkInstance instance;
	VkSurfaceKHR surface;
	VkDevice device;
	VkSwapchainKHR swapchain;

	VkSurfaceCapabilitiesKHR surface_capabilities;
	uint32_t graphics_queue_family_index;
	uint32_t present_queue_family_index;
	VkSurfaceFormatKHR surface_format;
	VkPresentModeKHR present_mode;

	bool mapped;

	bool visible;

	/* current canvas size */
	struct
	{
		int x, y, w, h;
	} canvas;

	/* swapchain render targets */
	uint32_t swapchain_image_count;
	struct
	{
		/* owned by the swapchain */
		VkImage image;
		/* owned by us */
		VkImageView image_view;
	} *swapchain_images;
};
