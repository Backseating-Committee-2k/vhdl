#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_renderpass.h"

#include "bss2kdpy.h"

#include <assert.h>

bool vulkan_renderpass_setup(struct global *g)
{
	VkAttachmentDescription const attachment_descriptions[] =
	{
		{
			.format = g->surface_format.format,
			.samples = VK_SAMPLE_COUNT_1_BIT,
			.loadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			.storeOp = VK_ATTACHMENT_STORE_OP_STORE,
			.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
			.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
			.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
		}
	};

	VkAttachmentReference const color_attachments[] =
	{
		{
			.attachment = 0,
			.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
		}
	};

	VkSubpassDescription const subpasses[] =
	{
		{
			.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
			.colorAttachmentCount =
					sizeof color_attachments / sizeof color_attachments[0],
			.pColorAttachments = color_attachments
		}
	};

	VkSubpassDependency const dependencies[] =
	{
		{
			.srcSubpass = VK_SUBPASS_EXTERNAL,
			.dstSubpass = 0,
			.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			.srcAccessMask = 0,
			.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
		}
	};

	VkRenderPassCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
		.attachmentCount =
				sizeof attachment_descriptions /
					sizeof attachment_descriptions[0],
		.pAttachments = attachment_descriptions,
		.subpassCount = sizeof subpasses / sizeof subpasses[0],
		.pSubpasses = subpasses,
		.dependencyCount = sizeof dependencies / sizeof dependencies[0],
		.pDependencies = dependencies
	};

	VkResult rc = vkCreateRenderPass(
			g->device,
			&info,
			g->allocation_callbacks,
			&g->render_pass);
	if(rc != VK_SUCCESS)
		return false;

	return true;
}

void vulkan_renderpass_teardown(struct global *g)
{
	if(g->render_pass != VK_NULL_HANDLE)
	{
		vkDestroyRenderPass(
				g->device,
				g->render_pass,
				g->allocation_callbacks);
		g->render_pass = VK_NULL_HANDLE;
	}
}
