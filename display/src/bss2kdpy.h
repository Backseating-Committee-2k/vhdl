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

	VkSurfaceFormatKHR surface_format;
	VkPresentModeKHR present_mode;

	bool mapped;

	bool visible;

	/* current canvas size */
	struct
	{
		int x, y, w, h;
	} canvas;
};
