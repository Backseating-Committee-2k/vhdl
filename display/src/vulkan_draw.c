#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_draw.h"

#include "bss2kdpy.h"

#include <assert.h>

bool vulkan_draw(struct global *g)
{
	uint32_t image_index;

	vkAcquireNextImageKHR(
			g->device,
			g->swapchain,
			/* timeout */ UINT64_MAX,
			/* semaphore */ g->sem.image_available,
			/* fence */ VK_NULL_HANDLE,
			&image_index);

	assert(image_index < g->swapchain_image_count);

	bool start = !g->drawing;

	/* if not starting, sync and stop first */
	if(!start)
		vulkan_draw_stop(g);

	/* if starting, fence may not be in ready state yet */
	if(start)
		assert(vkGetFenceStatus(g->device, g->fence.in_flight) == VK_NOT_READY);

	g->drawing = true;

	VkCommandBuffer const buffer = g->graphics_command_buffers[0];

	vkResetCommandBuffer(
			buffer,
			/* flags */ 0);

	/* begin command buffer */
	{
		VkCommandBufferBeginInfo const info =
		{
			.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
			.flags = 0,
			.pInheritanceInfo = NULL
		};

		VkResult rc = vkBeginCommandBuffer(buffer, &info);
		if(rc != VK_SUCCESS)
			goto fail_begin_command_buffer;
	}

	/* queue "begin render pass" */
	{
		VkClearValue const clear_values[] =
		{
			{
				.color =
				{
					.float32 =
					{
						0.0f, 0.0f, 0.0f, 1.0f
					}
				}
			}
		};

		VkRenderPassBeginInfo const info =
		{
			.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
			.renderPass = g->render_pass,
			.framebuffer = g->swapchain_images[image_index].framebuffer,
			.renderArea =
			{
				.offset =
				{
					.x = 0,
					.y = 0
				},
				.extent =
				{
					.width = g->canvas.w,
					.height = g->canvas.h
				}
			},
			.clearValueCount = sizeof clear_values / sizeof clear_values[0],
			.pClearValues = clear_values
		};

		vkCmdBeginRenderPass(buffer, &info, VK_SUBPASS_CONTENTS_INLINE);
	}

	vkCmdBindPipeline(
			buffer,
			VK_PIPELINE_BIND_POINT_GRAPHICS,
			g->pipelines[0]);

	vkCmdDraw(
			buffer,
			/* vertexCount */ 4,
			/* instanceCount */ 1,
			/* firstVertex */ 0,
			/* firstInstance */ 0);

	vkCmdEndRenderPass(buffer);

	VkResult rc = vkEndCommandBuffer(buffer);
	if(rc != VK_SUCCESS)
		goto fail_end_command_buffer;

	{
		VkSemaphore const wait_semaphores[] =
		{
			g->sem.image_available
		};

		VkPipelineStageFlags wait_stages[] =
		{
			VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
		};

		VkSemaphore const signal_semaphores[] =
		{
			g->sem.render_finished
		};

		/* these arrays correspond with each other and need to have the
		 * same length */
		_Static_assert(sizeof wait_semaphores / sizeof wait_semaphores[0] ==
					sizeof wait_stages / sizeof wait_stages[0]);

		VkCommandBuffer const command_buffers[] =
		{
			buffer
		};

		VkSubmitInfo const infos[] =
		{
			{
				.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
				.waitSemaphoreCount =
						sizeof wait_semaphores / sizeof wait_semaphores[0],
				.pWaitSemaphores = wait_semaphores,
				.pWaitDstStageMask = wait_stages,
				.commandBufferCount =
						sizeof command_buffers / sizeof command_buffers[0],
				.pCommandBuffers = command_buffers,
				.signalSemaphoreCount =
						sizeof signal_semaphores / sizeof signal_semaphores[0],
				.pSignalSemaphores = signal_semaphores
			}
		};

		VkResult rc = vkQueueSubmit(
				g->queue.graphics.queue,
				sizeof infos / sizeof infos[0],
				infos,
				g->fence.in_flight);
		if(rc != VK_SUCCESS)
			goto fail_queue_submit;
	}

	{
		VkSemaphore const wait_semaphores[] =
		{
			g->sem.render_finished
		};

		VkSwapchainKHR const swapchains[] =
		{
			g->swapchain
		};

		uint32_t const image_indices[] =
		{
			image_index
		};

		_Static_assert(sizeof swapchains / sizeof swapchains[0] ==
					sizeof image_indices / sizeof image_indices[0]);

		VkPresentInfoKHR const info =
		{
			.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
			.waitSemaphoreCount =
					sizeof wait_semaphores / sizeof wait_semaphores[0],
			.pWaitSemaphores = wait_semaphores,
			.swapchainCount =
					sizeof swapchains / sizeof swapchains[0],
			.pSwapchains = swapchains,
			.pImageIndices = image_indices
		};

		VkResult rc = vkQueuePresentKHR(
				g->queue.present.queue,
				&info);
		if(rc != VK_SUCCESS)
			goto fail_queue_present;
	}

	return true;

fail_queue_present:
fail_queue_submit:
fail_end_command_buffer:
fail_begin_command_buffer:
	return false;

}

void vulkan_draw_stop(struct global *g)
{
	if(!g->drawing)
		return;

	VkFence const fences[] =
	{
		g->fence.in_flight
	};

	vkWaitForFences(
			g->device,
			sizeof fences / sizeof fences[0],
			fences,
			/* waitAll */ VK_TRUE,
			/* timeout */ UINT64_MAX);
	vkResetFences(
			g->device,
			sizeof fences / sizeof fences[0],
			fences);

	g->drawing = false;
}
