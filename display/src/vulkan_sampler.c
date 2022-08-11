#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_sampler.h"

#include <vulkan/vulkan.h>

#include "bss2kdpy.h"

bool vulkan_sampler_setup(struct global *g)
{
	VkSamplerCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
		.magFilter = VK_FILTER_LINEAR,
		.minFilter = VK_FILTER_LINEAR,
		.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
		.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
		.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
		.anisotropyEnable = VK_TRUE,
		.maxAnisotropy = g->limits.max_sampler_anisotropy,
		.borderColor = VK_BORDER_COLOR_INT_OPAQUE_BLACK,
		.unnormalizedCoordinates = VK_FALSE,
		.compareEnable = VK_FALSE,
		.compareOp = VK_COMPARE_OP_ALWAYS,
		.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR,
		.mipLodBias = 0.0f,
		.minLod = 0.0f,
		.maxLod = 0.0f
	};

	VkResult rc = vkCreateSampler(
			g->device,
			&info,
			g->allocation_callbacks,
			&g->textmode_texture_sampler);
	if(rc != VK_SUCCESS)
		return false;

	return true;
}

void vulkan_sampler_teardown(struct global *g)
{
	if(g->textmode_texture_sampler != VK_NULL_HANDLE)
	{
		vkDestroySampler(
				g->device,
				g->textmode_texture_sampler,
				g->allocation_callbacks);
		g->textmode_texture_sampler = VK_NULL_HANDLE;
	}
}
