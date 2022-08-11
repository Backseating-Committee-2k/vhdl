#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_descriptor_set_layout.h"

#include "bss2kdpy.h"

bool vulkan_descriptor_set_layout_setup(struct global *g)
{
	VkDescriptorSetLayoutBinding const bindings[] =
	{
		{
			.binding = TEXTMODE_TEXTURE_AND_SAMPLER_BINDING,
			.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
			.descriptorCount = 1,	// not an array
			.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT,
			.pImmutableSamplers = NULL
		}
	};

	VkDescriptorSetLayoutCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		.pNext = NULL,
		.flags = 0,
		.bindingCount = sizeof bindings /
				sizeof bindings[0],
		.pBindings = bindings
	};

	VkResult rc = vkCreateDescriptorSetLayout(
			g->device,
			&info,
			g->allocation_callbacks,
			&g->descriptor_set_layout);
	if(rc != VK_SUCCESS)
		return false;

	return true;
}

void vulkan_descriptor_set_layout_teardown(struct global *g)
{
	if(&g->descriptor_set_layout != VK_NULL_HANDLE)
	{
		vkDestroyDescriptorSetLayout(
				g->device,
				g->descriptor_set_layout,
				g->allocation_callbacks);
		g->descriptor_set_layout = VK_NULL_HANDLE;
	}
}
