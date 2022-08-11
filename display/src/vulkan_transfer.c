#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "vulkan_transfer.h"

#include "bss2kdpy.h"

bool vulkan_transfer(struct global *g)
{
	// TODO
	VkCommandBuffer const buffer = g->graphics_command_buffers[1];

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

	{
		VkImageMemoryBarrier const image_memory_barriers[] =
		{
			{
				.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
				.oldLayout = VK_IMAGE_LAYOUT_PREINITIALIZED,
				.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
				.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
				.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
				.image = g->textmode_texture_external.image,
				.subresourceRange =
				{
					.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
					.baseMipLevel = 0,
					.levelCount = 1,
					.baseArrayLayer = 0,
					.layerCount = 1
				},
				.srcAccessMask = 0,
				.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT
			}
		};

		vkCmdPipelineBarrier(
				buffer,
				VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
				VK_PIPELINE_STAGE_TRANSFER_BIT,
				/* flags */ 0,
				/* memoryBarrierCount */ 0,
				/* pMemoryBarriers */ NULL,
				/* bufferMemoryBarrierCount */ 0,
				/* pBufferMemoryBarriers */ NULL,
				sizeof image_memory_barriers /
					sizeof image_memory_barriers[0],
				image_memory_barriers);
	}

	{
		VkImageMemoryBarrier const image_memory_barriers[] =
		{
			{
				.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
				.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED,
				.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
				.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
				.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
				.image = g->textmode_texture_internal.image,
				.subresourceRange =
				{
					.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
					.baseMipLevel = 0,
					.levelCount = 1,
					.baseArrayLayer = 0,
					.layerCount = 1
				},
				.srcAccessMask = 0,
				.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT
			}
		};

		vkCmdPipelineBarrier(
				buffer,
				VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
				VK_PIPELINE_STAGE_TRANSFER_BIT,
				/* flags */ 0,
				/* memoryBarrierCount */ 0,
				/* pMemoryBarriers */ NULL,
				/* bufferMemoryBarrierCount */ 0,
				/* pBufferMemoryBarriers */ NULL,
				sizeof image_memory_barriers /
					sizeof image_memory_barriers[0],
				image_memory_barriers);
	}

	{
		VkImageCopy const regions[] =
		{
			{
				.srcSubresource =
				{
					.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
					.mipLevel = 0,
					.baseArrayLayer = 0,
					.layerCount = 1
				},
				.srcOffset =
				{
					.x = 0,
					.y = 0,
					.z = 0
				},
				.dstSubresource =
				{
					.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
					.mipLevel = 0,
					.baseArrayLayer = 0,
					.layerCount = 1
				},
				.dstOffset =
				{
					.x = 0,
					.y = 0,
					.z = 0
				},
				.extent =
				{
					.width = SCREEN_WIDTH,
					.height = SCREEN_HEIGHT,
					.depth = 1
				}
			}
		};

		vkCmdCopyImage(
				buffer,
				g->textmode_texture_external.image,
				VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
				g->textmode_texture_internal.image,
				VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
				sizeof regions / sizeof regions[0],
				regions);
	}

	{
		VkImageMemoryBarrier const image_memory_barriers[] =
		{
			{
				.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
				.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
				.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
				.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
				.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
				.image = g->textmode_texture_internal.image,
				.subresourceRange =
				{
					.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
					.baseMipLevel = 0,
					.levelCount = 1,
					.baseArrayLayer = 0,
					.layerCount = 1
				},
				.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
				.dstAccessMask = VK_ACCESS_SHADER_READ_BIT
			}
		};

		vkCmdPipelineBarrier(
				buffer,
				VK_PIPELINE_STAGE_TRANSFER_BIT,
				VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
				/* flags */ 0,
				/* memoryBarrierCount */ 0,
				/* pMemoryBarriers */ NULL,
				/* bufferMemoryBarrierCount */ 0,
				/* pBufferMemoryBarriers */ NULL,
				sizeof image_memory_barriers /
					sizeof image_memory_barriers[0],
				image_memory_barriers);
	}

	VkResult rc = vkEndCommandBuffer(buffer);
	if(rc != VK_SUCCESS)
		goto fail_end_command_buffer;

	{
		VkSemaphore const wait_semaphores[] =
		{
		};

		VkPipelineStageFlags wait_stages[] =
		{
		};

		VkSemaphore const signal_semaphores[] =
		{
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
				VK_NULL_HANDLE);
		if(rc != VK_SUCCESS)
			goto fail_queue_submit;
	}

	return true;

fail_queue_submit:
fail_end_command_buffer:
fail_begin_command_buffer:
	return false;
}
