#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_shader.h"

#include "bss2kdpy.h"

static VkResult create_shader(
		struct global *g,
		unsigned char const *code_begin,
		unsigned char const *code_end,
		VkShaderModule *out_shader)
{
	VkShaderModuleCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
		.codeSize = code_end - code_begin,
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
	extern unsigned char const _binary_frag_spv_start[];
	extern unsigned char const _binary_frag_spv_end[];

	VkResult rc = create_shader(
			g,
			_binary_frag_spv_start,
			_binary_frag_spv_end,
			&g->shaders.frag);
	if(rc != VK_SUCCESS)
		goto fail;

	extern unsigned char const _binary_vert_spv_start[];
	extern unsigned char const _binary_vert_spv_end[];

	rc = create_shader(
			g,
			_binary_vert_spv_start,
			_binary_vert_spv_end,
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
