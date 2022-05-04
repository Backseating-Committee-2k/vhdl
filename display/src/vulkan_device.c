#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_instance.h"

#include "bss2kdpy.h"

bool vulkan_device_setup(struct global *g)
{
	VkPhysicalDevice selected_physical_device;
	uint32_t graphics_queue_family_index;
	uint32_t present_queue_family_index;

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

		if(have_graphics_queue_family_index &&
				have_present_queue_family_index)
		{
			selected_physical_device = physical_device;
			have_selected_physical_device = true;
			break;
		}
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
