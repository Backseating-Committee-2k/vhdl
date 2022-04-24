#pragma once

#include <vulkan/vulkan.h>

struct global
{
	VkAllocationCallbacks *allocation_callbacks;

	VkInstance instance;
};
