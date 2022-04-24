#pragma once

#include <X11/Xlib.h>

#include <vulkan/vulkan.h>

struct global
{
	union
	{
		struct
		{
			Display *display;
		} x11;
	};

	VkAllocationCallbacks *allocation_callbacks;

	VkInstance instance;
};
