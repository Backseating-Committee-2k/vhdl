#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_sync.h"

#include "bss2kdpy.h"

static bool create_semaphore(struct global *g, VkSemaphore *ret)
{
	VkSemaphoreCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
	};

	VkResult rc = vkCreateSemaphore(
			g->device,
			&info,
			g->allocation_callbacks,
			ret);
	return rc == VK_SUCCESS;
}

static VkSemaphore destroy_semaphore(struct global *g, VkSemaphore sem)
{
	if(sem != VK_NULL_HANDLE)
		vkDestroySemaphore(
				g->device,
				sem,
				g->allocation_callbacks);
	return VK_NULL_HANDLE;
}

static bool create_fence(struct global *g, VkFence *ret)
{
	VkFenceCreateInfo const info =
	{
		.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
	};

	VkResult rc = vkCreateFence(
			g->device,
			&info,
			g->allocation_callbacks,
			ret);
	return rc == VK_SUCCESS;
}

static VkFence destroy_fence(struct global *g, VkFence fence)
{
	if(fence != VK_NULL_HANDLE)
		vkDestroyFence(g->device, fence, g->allocation_callbacks);
	return VK_NULL_HANDLE;
}

/* fences are created in "signaled" state */
bool vulkan_sync_setup(struct global *g)
{
	if(!create_semaphore(g, &g->sem.image_available))
		goto fail_create_semaphore;
	if(!create_semaphore(g, &g->sem.render_finished))
		goto fail_create_semaphore;
	if(!create_fence(g, &g->fence.in_flight))
		goto fail_create_fence;

	return true;

fail_create_fence:
fail_create_semaphore:
	vulkan_sync_teardown(g);

	return false;
}

void vulkan_sync_teardown(struct global *g)
{
	g->fence.in_flight =
			destroy_fence(g, g->fence.in_flight);
	g->sem.render_finished =
			destroy_semaphore(g, g->sem.render_finished);
	g->sem.image_available =
			destroy_semaphore(g, g->sem.image_available);
}
