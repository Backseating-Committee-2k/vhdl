#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_pipeline.h"

#include "bss2kdpy.h"

bool vulkan_pipeline_setup(struct global *g)
{
	VkPipelineLayoutCreateInfo const pipeline_layout_info =
	{
		.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
		.pNext = NULL,
		.flags = 0,
		.setLayoutCount = 0,
		.pSetLayouts = NULL,
		.pushConstantRangeCount = 0,
		.pPushConstantRanges = NULL
	};

	VkResult rc = vkCreatePipelineLayout(
			g->device,
			&pipeline_layout_info,
			g->allocation_callbacks,
			&g->pipeline_layout);
	if(rc != VK_SUCCESS)
		goto fail_pipeline_layout;

	return true;

fail_pipeline_layout:
	return false;
}

void vulkan_pipeline_teardown(struct global *g)
{
	if(g->pipeline_layout != VK_NULL_HANDLE)
	{
		vkDestroyPipelineLayout(
				g->device,
				g->pipeline_layout,
				g->allocation_callbacks);
		g->pipeline_layout = VK_NULL_HANDLE;
	}
}
