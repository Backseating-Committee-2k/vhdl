#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_vulkan.h"
#include "x11_setup.h"
#include "x11_mainloop.h"
#include "vulkan_instance.h"
#include "vulkan_device.h"
#include "vulkan_external_texture.h"
#include "vulkan_texture.h"
#include "vulkan_sampler.h"
#include "vulkan_sync.h"
#include "vulkan_descriptor_set_layout.h"
#include "vulkan_descriptor_pool.h"
#include "vulkan_command_pool.h"
#include "vulkan_command_buffer.h"
#include "vulkan_swapchain.h"
#include "vulkan_shader.h"
#include "vulkan_renderpass.h"
#include "vulkan_pipeline.h"

#include "bss2kdpy.h"

#include <unistd.h>

int main(int argc, char **argv)
{
	int rc = 1;

	struct global g =
	{
		.argc = argc,
		.argv = argv
	};

	if(!x11_setup(&g))
		goto fail_x11;

	if(!vulkan_instance_setup(&g))
		goto fail_vulkan_instance;

	if(!x11_vulkan_setup(&g))
		goto fail_x11_vulkan;

	if(!vulkan_device_setup(&g))
		goto fail_vulkan_device;

	if(!vulkan_external_texture_setup(&g))
		goto fail_vulkan_external_texture;

	if(!vulkan_texture_setup(&g))
		goto fail_vulkan_texture;

	if(!vulkan_sampler_setup(&g))
		goto fail_vulkan_sampler;

	if(!vulkan_sync_setup(&g))
		goto fail_vulkan_sync;

	if(!vulkan_descriptor_set_layout_setup(&g))
		goto fail_vulkan_descriptor_set_layout;

	if(!vulkan_descriptor_pool_setup(&g))
		goto fail_vulkan_descriptor_pool;

	if(!vulkan_command_pool_setup(&g))
		goto fail_vulkan_command_pool;

	if(!vulkan_command_buffer_setup(&g))
		goto fail_vulkan_command_buffer;

	if(!vulkan_shader_setup(&g))
		goto fail_vulkan_shader;

	if(!vulkan_renderpass_setup(&g))
		goto fail_vulkan_renderpass;

	if(!x11_mainloop(&g))
		goto fail_x11_mainloop;

	// success starts here
	rc = 0;

fail_x11_mainloop:
	/* shouldn't be necessary */
	vulkan_pipeline_teardown(&g);

	vulkan_renderpass_teardown(&g);

fail_vulkan_renderpass:
	/* shouldn't be necessary */
	vulkan_swapchain_teardown(&g);

	vulkan_shader_teardown(&g);

fail_vulkan_shader:
	vulkan_command_buffer_teardown(&g);

fail_vulkan_command_buffer:
	vulkan_command_pool_teardown(&g);

fail_vulkan_command_pool:
	vulkan_descriptor_pool_teardown(&g);

fail_vulkan_descriptor_pool:
	vulkan_descriptor_set_layout_teardown(&g);

fail_vulkan_descriptor_set_layout:
	vulkan_sync_teardown(&g);

fail_vulkan_sync:
	vulkan_sampler_teardown(&g);

fail_vulkan_sampler:
	vulkan_texture_teardown(&g);

fail_vulkan_texture:
	vulkan_external_texture_teardown(&g);

fail_vulkan_external_texture:
	vulkan_device_teardown(&g);

fail_vulkan_device:
	x11_vulkan_teardown(&g);

fail_x11_vulkan:
	vulkan_instance_teardown(&g);

fail_vulkan_instance:
	x11_teardown(&g);

fail_x11:
	return rc;
}
