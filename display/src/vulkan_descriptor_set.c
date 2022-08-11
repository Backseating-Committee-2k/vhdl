#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_descriptor_set.h"

#include "bss2kdpy.h"

bool vulkan_descriptor_set_setup(struct global *g)
{
	VkDescriptorSetAllocateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
		.pNext = NULL,
		.descriptorPool = g->descriptor_pool,
		.descriptorSetCount = 1,
		.pSetLayouts = &g->descriptor_set_layout
	};

	VkResult rc = vkAllocateDescriptorSets(
			g->device,
			&info,
			&g->textmode_descriptor_set);
	if(rc != VK_SUCCESS)
		return false;

	VkDescriptorImageInfo const image_descriptor_info =
	{
		.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
		.imageView = g->textmode_texture_internal.image_view,
		.sampler = g->textmode_texture_sampler
	};

	VkWriteDescriptorSet const write_descriptors[] =
	{
		{
			.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
			.dstSet = g->textmode_descriptor_set,
			.dstBinding = TEXTMODE_TEXTURE_AND_SAMPLER_BINDING,
			.dstArrayElement = 0,
			.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
			.descriptorCount = 1,
			.pImageInfo = &image_descriptor_info
		}
	};

	vkUpdateDescriptorSets(
			g->device,
			sizeof write_descriptors / sizeof write_descriptors[0],
			write_descriptors,
			/* descriptorCopyCount */ 0,
			/* pDescriptorCopies */ NULL);

	return true;
}

void vulkan_descriptor_set_teardown(struct global *g)
{
	/* descriptor sets will be freed by freeing the pool */
	g->textmode_descriptor_set = VK_NULL_HANDLE;
}
