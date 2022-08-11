#pragma once

#include <stdbool.h>

#include <vulkan/vulkan.h>

struct global;

/* create a texture in device memory */
bool vulkan_texture_create(
		struct global *g,
		uint32_t width,
		uint32_t height,
		VkImage *out_image,
		VkDeviceMemory *out_memory);

/* destroy a texture and its memory */
void vulkan_texture_destroy(
		struct global *g,
		VkImage image,
		VkDeviceMemory memory);

bool vulkan_texture_setup(struct global *g);
void vulkan_texture_teardown(struct global *g);
