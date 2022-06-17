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

	VkPipelineShaderStageCreateInfo const shader_info[] =
	{
		{
			.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = VK_SHADER_STAGE_VERTEX_BIT,
			.module = g->shaders.vert,
			.pName = "main"
		},
		{
			.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = VK_SHADER_STAGE_FRAGMENT_BIT,
			.module = g->shaders.frag,
			.pName = "main"
		}
	};

	VkPipelineVertexInputStateCreateInfo const vertex_input_info =
	{
		.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		.vertexBindingDescriptionCount = 0,
		.pVertexBindingDescriptions = NULL,
		.vertexAttributeDescriptionCount = 0,
		.pVertexAttributeDescriptions = NULL
	};

	VkPipelineInputAssemblyStateCreateInfo const input_assembly_info =
	{
		.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP,
		.primitiveRestartEnable = VK_FALSE
	};

	VkViewport const viewports[] =
	{
		{
			.x = 0.0f,
			.y = 0.0f,
			.width = (float)g->canvas.w,
			.height = (float)g->canvas.h,
			.minDepth = 0.0f,
			.maxDepth = 1.0f
		}
	};

	VkRect2D const scissors[] =
	{
		{
			.offset =
			{
				.x = 0.0f,
				.y = 0.0f
			},
			.extent =
			{
				.width = (float)g->canvas.w,
				.height = (float)g->canvas.h
			}
		}
	};

	VkPipelineViewportStateCreateInfo const viewport_info =
	{
		.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		.viewportCount = sizeof viewports / sizeof viewports[0],
		.pViewports = viewports,
		.scissorCount = sizeof scissors / sizeof scissors[0],
		.pScissors = scissors
	};

	VkPipelineRasterizationStateCreateInfo const rasterization_info =
	{
		.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		.depthClampEnable = VK_FALSE,
		.rasterizerDiscardEnable = VK_FALSE,
		.polygonMode = VK_POLYGON_MODE_FILL,
		.lineWidth = 1.0f,
		.cullMode = VK_CULL_MODE_BACK_BIT,
		.frontFace = VK_FRONT_FACE_CLOCKWISE,
		.depthBiasEnable = VK_FALSE,
		.depthBiasConstantFactor = 0.0f,
		.depthBiasClamp = 0.0f,
		.depthBiasSlopeFactor = 0.0f
	};

	VkPipelineMultisampleStateCreateInfo const multisample_info =
	{
		.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		.sampleShadingEnable = VK_FALSE,
		.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
		.minSampleShading = 1.0f,
		.pSampleMask = NULL,
		.alphaToCoverageEnable = VK_FALSE,
		.alphaToOneEnable = VK_FALSE
	};

	VkPipelineColorBlendAttachmentState const color_blend_attachments[] =
	{
		{
			.colorWriteMask =
					VK_COLOR_COMPONENT_R_BIT |
					VK_COLOR_COMPONENT_G_BIT |
					VK_COLOR_COMPONENT_B_BIT |
					VK_COLOR_COMPONENT_A_BIT,
			.blendEnable = VK_FALSE,
			.srcColorBlendFactor = VK_BLEND_FACTOR_ONE,
			.dstColorBlendFactor = VK_BLEND_FACTOR_ZERO,
			.colorBlendOp = VK_BLEND_OP_ADD,
			.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE,
			.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO,
			.alphaBlendOp = VK_BLEND_OP_ADD
		}
	};

	VkPipelineColorBlendStateCreateInfo const color_blend_info =
	{
		.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		.logicOpEnable = VK_FALSE,
		.logicOp = VK_LOGIC_OP_COPY,
		.attachmentCount = sizeof color_blend_attachments /
				sizeof color_blend_attachments[0],
		.pAttachments = color_blend_attachments,
		.blendConstants =
		{
			[0] = 0.0f,
			[1] = 0.0f,
			[2] = 0.0f,
			[3] = 0.0f
		}
	};

	VkDynamicState const dynamic_states[] =
	{
	};

	VkPipelineDynamicStateCreateInfo const dynamic_info =
	{
		.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		.dynamicStateCount = sizeof dynamic_states / sizeof dynamic_states[0],
		.pDynamicStates = dynamic_states
	};

	VkGraphicsPipelineCreateInfo const infos[] =
	{
		{
			.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
			.stageCount = sizeof shader_info / sizeof shader_info[0],
			.pStages = shader_info,
			.pVertexInputState = &vertex_input_info,
			.pInputAssemblyState = &input_assembly_info,
			.pViewportState = &viewport_info,
			.pRasterizationState = &rasterization_info,
			.pMultisampleState = &multisample_info,
			.pColorBlendState = &color_blend_info,
			.pDynamicState = &dynamic_info,
			.layout = g->pipeline_layout,
			.renderPass = g->render_pass,
			.subpass = 0,
			.basePipelineHandle = VK_NULL_HANDLE,
			.basePipelineIndex = -1
		}
	};

	/* check that output array has the correct size */
	_Static_assert(
			sizeof infos / sizeof infos[0] ==
			sizeof g->pipelines / sizeof g->pipelines[0]);

	rc = vkCreateGraphicsPipelines(
			g->device,
			VK_NULL_HANDLE,
			sizeof infos / sizeof infos[0],
			infos,
			g->allocation_callbacks,
			g->pipelines);
	if(rc != VK_SUCCESS)
		goto fail_graphics_pipelines;

	return true;

fail_graphics_pipelines:
	vkDestroyPipelineLayout(
			g->device,
			g->pipeline_layout,
			g->allocation_callbacks);
	g->pipeline_layout = VK_NULL_HANDLE;

fail_pipeline_layout:
	return false;
}

void vulkan_pipeline_teardown(struct global *g)
{
	for(size_t i = 0; i < sizeof g->pipelines / sizeof g->pipelines[0]; ++i)
	{
		if(g->pipelines[i] == VK_NULL_HANDLE)
			continue;
		vkDestroyPipeline(
				g->device,
				g->pipelines[i],
				g->allocation_callbacks);
		g->pipelines[i] = VK_NULL_HANDLE;
	}
	if(g->pipeline_layout != VK_NULL_HANDLE)
	{
		vkDestroyPipelineLayout(
				g->device,
				g->pipeline_layout,
				g->allocation_callbacks);
		g->pipeline_layout = VK_NULL_HANDLE;
	}
}
