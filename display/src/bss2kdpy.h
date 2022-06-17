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
	VkPhysicalDevice physical_device;
	VkDevice device;
	struct
	{
		struct
		{
			uint32_t family_index;
			VkQueue queue;
		} graphics, present;
	} queue;
	struct
	{
		VkSemaphore image_available;
		VkSemaphore render_finished;
	} sem;
	struct
	{
		VkFence in_flight;
	} fence;
	VkSwapchainKHR swapchain;
	VkRenderPass render_pass;
	VkPipelineLayout pipeline_layout;
	VkPipeline pipelines[1];
	VkCommandPool graphics_command_pool;
	VkCommandBuffer graphics_command_buffers[1];

	VkSurfaceFormatKHR surface_format;
	VkPresentModeKHR present_mode;

	/* shutting down, don't start new things */
	bool shutdown;

	/* window currently mapped */
	bool mapped;

	/* window currently visible */
	bool visible;

	/* current canvas size */
	struct
	{
		int x, y, w, h;
	} canvas;

	struct
	{
		VkShaderModule frag;
		VkShaderModule vert;
	} shaders;

	/* swapchain render targets */
	uint32_t swapchain_image_count;
	struct
	{
		/* owned by the swapchain */
		VkImage image;
		/* owned by us */
		VkImageView image_view;
		VkFramebuffer framebuffer;
	} *swapchain_images;
};
