#pragma once

#include <X11/Xlib.h>

#include <vulkan/vulkan.h>

#include <stdbool.h>

#define SCREEN_WIDTH 480
#define SCREEN_HEIGHT 360

/* binding numbers, keep consistent with shaders */
#define TEXTMODE_TEXTURE_AND_SAMPLER_BINDING 0

struct global
{
	int argc;
	char **argv;

	int bss2k_device;

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

	VkDescriptorSetLayout descriptor_set_layout;
	VkDescriptorPool descriptor_pool;

	VkSampler textmode_texture_sampler;

	VkDescriptorSet textmode_descriptor_set;

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
	VkCommandBuffer graphics_command_buffers[2];

	VkSurfaceFormatKHR surface_format;
	VkPresentModeKHR present_mode;

	/* bitmask of device local memory types */
	uint32_t device_local_memory_types;

	struct
	{
		float max_sampler_anisotropy;
	} limits;

	/* shutting down, don't start new things */
	bool shutdown;

	/* window currently mapped */
	bool mapped;

	/* window currently visible */
	bool visible;

	/* GPU busy (more likely, status not collected) */
	bool drawing;

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

	/* textures and their associated memory */
	struct
	{
		VkImage image;
		VkImageView image_view;
		VkDeviceMemory memory;
	}
	/* texture in FPGA address space, linear layout */
	textmode_texture_external,
	/* texture in GPU address space, optimized layout */
	textmode_texture_internal;

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
