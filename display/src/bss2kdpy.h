#pragma once

#include <X11/Xlib.h>

#include <vulkan/vulkan.h>

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
};
