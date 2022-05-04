#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_instance.h"

#include "bss2kdpy.h"

#include <string.h>

bool vulkan_device_setup(struct global *g)
{
	VkPhysicalDevice selected_physical_device;
	uint32_t graphics_queue_family_index;
	uint32_t present_queue_family_index;
	VkSurfaceFormatKHR surface_format;

	bool have_selected_physical_device = false;

	uint32_t physical_device_count = 0;

	VkResult rc = vkEnumeratePhysicalDevices(
			g->instance,
			&physical_device_count,
			NULL);
	if(rc != VK_SUCCESS)
		return false;

	VkPhysicalDevice physical_devices[physical_device_count];

	rc = vkEnumeratePhysicalDevices(
			g->instance,
			&physical_device_count,
			physical_devices);
	if(rc != VK_SUCCESS)
		return false;

	for(uint32_t i = 0; i < physical_device_count; ++i)
	{
		VkPhysicalDevice const physical_device = physical_devices[i];

		VkPhysicalDeviceProperties pd_prop;

		vkGetPhysicalDeviceProperties(
				physical_device,
				&pd_prop);

		uint32_t extension_count = 0;

		rc = vkEnumerateDeviceExtensionProperties(
				physical_device,
				NULL,
				&extension_count,
				NULL);
		if(rc != VK_SUCCESS)
			continue;

		VkExtensionProperties extension_properties[extension_count];

		rc = vkEnumerateDeviceExtensionProperties(
				physical_device,
				NULL,
				&extension_count,
				extension_properties);
		if(rc != VK_SUCCESS)
			continue;

		bool have_swapchain_extension = false;

		for(uint32_t j = 0; j < extension_count; ++j)
		{
			if(!strcmp(extension_properties[j].extensionName,
					VK_KHR_SWAPCHAIN_EXTENSION_NAME))
				have_swapchain_extension = true;

			if(have_swapchain_extension)
				break;
		}

		if(!have_swapchain_extension)
			continue;

		uint32_t queue_family_count = 0;

		vkGetPhysicalDeviceQueueFamilyProperties(
				physical_device,
				&queue_family_count,
				NULL);

		VkQueueFamilyProperties qf_prop[queue_family_count];

		vkGetPhysicalDeviceQueueFamilyProperties(
				physical_device,
				&queue_family_count,
				qf_prop);

		bool have_graphics_queue_family_index = false;
		bool have_present_queue_family_index = false;

		for(uint32_t j = 0; j < queue_family_count; ++j)
		{
			bool const graphics_supported =
					!!(qf_prop->queueFlags &
						VK_QUEUE_GRAPHICS_BIT);

			VkBool32 present;

			rc = vkGetPhysicalDeviceSurfaceSupportKHR(
					physical_device,
					j,
					g->surface,
					&present);

			bool const present_supported =
					(rc == VK_SUCCESS) &&
					(present == VK_TRUE);

			bool const both_supported =
					present_supported &&
					graphics_supported;

			if(both_supported)
			{
				graphics_queue_family_index = j;
				have_graphics_queue_family_index = true;
				present_queue_family_index = j;
				have_present_queue_family_index = true;
				break;
			}

			if(graphics_supported &&
					!have_graphics_queue_family_index)
			{
				graphics_queue_family_index = j;
				have_graphics_queue_family_index = true;
			}
			if(present_supported &&
					!have_present_queue_family_index)
			{
				present_queue_family_index = j;
				have_present_queue_family_index = true;
			}
		}

		if(!have_graphics_queue_family_index)
			continue;

		if(!have_present_queue_family_index)
			continue;

		uint32_t surface_format_count = 0;

		vkGetPhysicalDeviceSurfaceFormatsKHR(
				physical_device,
				g->surface,
				&surface_format_count,
				NULL);

		if(surface_format_count == 0)
			continue;

		VkSurfaceFormatKHR surface_formats[surface_format_count];

		vkGetPhysicalDeviceSurfaceFormatsKHR(
				physical_device,
				g->surface,
				&surface_format_count,
				surface_formats);

		VkSurfaceFormatKHR const surface_format_preferences[] =
		{
			{
				.format = VK_FORMAT_B8G8R8A8_SRGB,
				.colorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
			},
			{
				.format = VK_FORMAT_B8G8R8A8_UNORM,
				.colorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
			}
		};

		uint32_t const surface_format_preference_count =
				sizeof surface_format_preferences /
					sizeof *surface_format_preferences;

		uint32_t best_surface_format_index =
				surface_format_preference_count;

		for(uint32_t j = 0; j < surface_format_count; ++j)
		{
			for(uint32_t k = 0; k < best_surface_format_index; ++k)
			{
				if(surface_format_preferences[k].format !=
						surface_formats[j].format)
					continue;
				if(surface_format_preferences[k].colorSpace !=
						surface_formats[j].colorSpace)
					continue;
				best_surface_format_index = k;
				surface_format = surface_formats[j];
				break;
			}
		}

		bool const have_surface_format =
				(best_surface_format_index <
					surface_format_preference_count);

		if(!have_surface_format)
			continue;

		// accept device
		selected_physical_device = physical_device;
		have_selected_physical_device = true;
		break;
	}

	if(!have_selected_physical_device)
		return false;

	float const queue_priorities[1] =
	{
		1.0f
	};

	VkDeviceQueueCreateInfo const queue_infos[2] =
	{
		{
			.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
			.pNext = NULL,
			.flags = 0,
			.queueFamilyIndex = graphics_queue_family_index,
			.queueCount = 1,
			.pQueuePriorities = queue_priorities
		},
		{
			.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
			.pNext = NULL,
			.flags = 0,
			.queueFamilyIndex = present_queue_family_index,
			.queueCount = 1,
			.pQueuePriorities = queue_priorities
		}
	};

	bool separate_queues = graphics_queue_family_index !=
			 present_queue_family_index;

	uint32_t const num_queues = separate_queues ? 2 : 1;

	char const *const enabled_layer_names[] =
	{
	};

	char const *const enabled_extension_names[] =
	{
		VK_KHR_SWAPCHAIN_EXTENSION_NAME
	};

	VkDeviceCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		.pNext = NULL,
		.flags = 0,
		.queueCreateInfoCount = num_queues,
		.pQueueCreateInfos = queue_infos,
		.enabledLayerCount = sizeof enabled_layer_names /
				sizeof *enabled_layer_names,
		.ppEnabledLayerNames = enabled_layer_names,
		.enabledExtensionCount = sizeof enabled_extension_names /
				sizeof *enabled_extension_names,
		.ppEnabledExtensionNames = enabled_extension_names,
		.pEnabledFeatures = NULL	/// @todo
	};

	g->surface_format = surface_format;

	rc = vkCreateDevice(
			selected_physical_device,
			&info,
			g->allocation_callbacks,
			&g->device);

	if(rc != VK_SUCCESS)
		return false;

	return true;
}

void vulkan_device_teardown(struct global *g)
{
	if(g->device != VK_NULL_HANDLE)
	{
		vkDestroyDevice(
			g->device,
			g->allocation_callbacks);
		g->device = VK_NULL_HANDLE;
	}
}
