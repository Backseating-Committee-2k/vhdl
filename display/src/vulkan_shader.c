#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_shader.h"

#include "bss2kdpy.h"

static VkResult create_shader(
		struct global *g,
		unsigned char const *code_begin,
		size_t code_size,
		VkShaderModule *out_shader)
{
	VkShaderModuleCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
		.codeSize = code_size,
		.pCode = (uint32_t *)code_begin
	};

	return vkCreateShaderModule(
			g->device,
			&info,
			g->allocation_callbacks,
			out_shader);
}

bool vulkan_shader_setup(struct global *g)
{
	unsigned char const frag_spv[] =
	{
#include "frag.inc"
	};

	VkResult rc = create_shader(
			g,
			frag_spv,
			sizeof frag_spv,
			&g->shaders.frag);
	if(rc != VK_SUCCESS)
		goto fail;

	unsigned char const vert_spv[] =
	{
#include "vert.inc"
	};

	rc = create_shader(
			g,
			vert_spv,
			sizeof vert_spv,
			&g->shaders.vert);
	if(rc != VK_SUCCESS)
		goto fail;

	return true;

fail:
	vulkan_shader_teardown(g);
	return false;
}

static void destroy_shader(
		struct global *g,
		VkShaderModule shader)
{
	if(shader != VK_NULL_HANDLE)
		vkDestroyShaderModule(
				g->device,
				shader,
				g->allocation_callbacks);
}

void vulkan_shader_teardown(struct global *g)
{
	destroy_shader(g, g->shaders.vert);
	g->shaders.vert = VK_NULL_HANDLE;
	destroy_shader(g, g->shaders.frag);
	g->shaders.frag = VK_NULL_HANDLE;
}
