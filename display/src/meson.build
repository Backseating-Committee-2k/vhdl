embed_src = [ 'embed.c' ]

embed = executable('embed', embed_src, native: true)

frag_spv = custom_target('build-frag-spv',
	input: 'texture.frag',
	output: 'frag.spv',
	command: [ glslangvalidator, '-V', '@INPUT@', '-o', '@OUTPUT@' ])

frag_inc = custom_target('build-frag-inc',
	input: frag_spv,
	output: 'frag.inc',
	command: [ embed, '@INPUT@', '@OUTPUT@' ])

vert_spv = custom_target('build-vert-spv',
	input: 'entire_viewport.vert',
	output: 'vert.spv',
	command: [ glslangvalidator, '-V', '@INPUT@', '-o', '@OUTPUT@' ])

vert_inc = custom_target('build-vert-inc',
	input: vert_spv,
	output: 'vert.inc',
	command: [ embed, '@INPUT@', '@OUTPUT@' ])

bss2kdpy_src = [
	'bss2kdpy.c', 'bss2kdpy.h',
	'device.c', 'device.h',
	'util.h',
	'vulkan_command_buffer.c', 'vulkan_command_buffer.h',
	'vulkan_command_pool.c', 'vulkan_command_pool.h',
	'vulkan_descriptor_pool.c', 'vulkan_descriptor_pool.h',
	'vulkan_descriptor_set.c', 'vulkan_descriptor_set.h',
	'vulkan_descriptor_set_layout.c', 'vulkan_descriptor_set_layout.h',
	'vulkan_device.c', 'vulkan_device.h',
	'vulkan_draw.c', 'vulkan_draw.h',
	'vulkan_external_texture.c', 'vulkan_external_texture.h',
	'vulkan_instance.c', 'vulkan_instance.h',
	'vulkan_pipeline.c', 'vulkan_pipeline.h',
	'vulkan_renderpass.c', 'vulkan_renderpass.h',
	'vulkan_sampler.c', 'vulkan_sampler.h',
	'vulkan_shader.c', 'vulkan_shader.h',
	'vulkan_swapchain.c', 'vulkan_swapchain.h',
	'vulkan_sync.c', 'vulkan_sync.h',
	'vulkan_texture.c', 'vulkan_texture.h',
	'vulkan_transfer.c', 'vulkan_transfer.h',
	'x11_mainloop.c', 'x11_mainloop.h',
	'x11_setup.c', 'x11_setup.h',
	'x11_vulkan.c', 'x11_vulkan.h',
	frag_inc, vert_inc
]

executable('bss2kdpy', bss2kdpy_src,
	dependencies: [ vulkan, x11 ])
