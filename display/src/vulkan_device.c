#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_instance.h"

#include "bss2kdpy.h"

#include <string.h>

bool vulkan_device_setup(struct global *g)
{
	char const *const required_extension_names[] =
	{
		VK_KHR_SWAPCHAIN_EXTENSION_NAME
	};
	uint32_t const required_extension_count =
			sizeof required_extension_names /
				sizeof required_extension_names[0];

	uint32_t graphics_queue_family_index;
	uint32_t present_queue_family_index;
	VkSurfaceFormatKHR surface_format;
	VkPresentModeKHR present_mode;
	float max_sampler_anisotropy;

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

		max_sampler_anisotropy = pd_prop.limits.maxSamplerAnisotropy;

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

		bool missing_an_extension = false;

		for(uint32_t j = 0; j < required_extension_count; ++j)
		{
			bool have_this_extension = false;

			for(uint32_t k = 0; k < extension_count; ++k)
			{
				if(!strcmp(extension_properties[k].extensionName,
						required_extension_names[j]))
					have_this_extension = true;

				if(have_this_extension)
					break;
			}

			if(!have_this_extension)
				missing_an_extension = true;

			if(missing_an_extension)
				break;
		}

		if(missing_an_extension)
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

		uint32_t present_mode_count = 0;

		vkGetPhysicalDeviceSurfacePresentModesKHR(
				physical_device,
				g->surface,
				&present_mode_count,
				NULL);

		if(present_mode_count == 0)
			continue;

		VkPresentModeKHR present_modes[present_mode_count];

		vkGetPhysicalDeviceSurfacePresentModesKHR(
				physical_device,
				g->surface,
				&present_mode_count,
				present_modes);

		VkPresentModeKHR const present_mode_preferences[] =
		{
			VK_PRESENT_MODE_MAILBOX_KHR,
			VK_PRESENT_MODE_FIFO_RELAXED_KHR,
			VK_PRESENT_MODE_IMMEDIATE_KHR,
			VK_PRESENT_MODE_FIFO_KHR,
			VK_PRESENT_MODE_SHARED_CONTINUOUS_REFRESH_KHR,
			// VK_PRESENT_MODE_SHARED_DEMAND_REFRESH_KHR
		};

		uint32_t const present_mode_preference_count =
				sizeof present_mode_preferences /
					sizeof *present_mode_preferences;

		uint32_t best_present_mode_index =
				present_mode_preference_count;

		for(uint32_t j = 0; j < present_mode_count; ++j)
		{
			for(uint32_t k = 0; k < best_present_mode_index; ++k)
			{
				if(present_mode_preferences[k] !=
						present_modes[j])
					continue;
				best_present_mode_index = k;
				present_mode = present_modes[j];
				break;
			}
		}

		bool const have_present_mode =
				(best_present_mode_index <
					present_mode_preference_count);

		if(!have_present_mode)
			continue;

		// accept device
		g->physical_device = physical_device;
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

	VkPhysicalDeviceFeatures const enabled_features =
	{
		/// @todo do not enable if unsupported
		.samplerAnisotropy = VK_TRUE
	};

	VkDeviceCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		.pNext = NULL,
		.flags = 0,
		.queueCreateInfoCount = num_queues,
		.pQueueCreateInfos = queue_infos,
		.enabledLayerCount = sizeof enabled_layer_names /
				sizeof enabled_layer_names[0],
		.ppEnabledLayerNames = enabled_layer_names,
		.enabledExtensionCount = required_extension_count,
		.ppEnabledExtensionNames = required_extension_names,
		.pEnabledFeatures = &enabled_features
	};

	g->queue.graphics.family_index = graphics_queue_family_index;
	g->queue.present.family_index = present_queue_family_index;
	g->surface_format = surface_format;
	g->present_mode = present_mode;
	g->limits.max_sampler_anisotropy = max_sampler_anisotropy;

	rc = vkCreateDevice(
			g->physical_device,
			&info,
			g->allocation_callbacks,
			&g->device);

	if(rc != VK_SUCCESS)
		return false;

	vkGetDeviceQueue(
			g->device,
			g->queue.graphics.family_index,
			0,
			&g->queue.graphics.queue);

	if(separate_queues)
		vkGetDeviceQueue(
				g->device,
				g->queue.present.family_index,
				0,
				&g->queue.present.queue);
	else
		g->queue.present.queue = g->queue.graphics.queue;

	{
		VkPhysicalDeviceMemoryProperties prop;
		vkGetPhysicalDeviceMemoryProperties(
				g->physical_device,
				&prop);
		
		uint32_t device_local_memory_types = 0u;

		for(uint32_t i = 0; i < VK_MAX_MEMORY_TYPES; ++i)
		{
			uint32_t const bit = ((uint32_t)1u) << i;
			if(prop.memoryTypes[i].propertyFlags &
					VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
				device_local_memory_types |= bit;
		}

		g->device_local_memory_types = device_local_memory_types;
	}

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
