bin_PROGRAMS = bss2kdpy

bss2kdpy_SOURCES = \
	bss2kdpy.c bss2kdpy.h \
	util.h \
	vulkan_instance.c vulkan_instance.h \
	vulkan_command_buffer.c vulkan_command_buffer.h \
	vulkan_command_pool.c vulkan_command_pool.h \
	vulkan_device.c vulkan_device.h \
	vulkan_draw.c vulkan_draw.h \
	vulkan_pipeline.c vulkan_pipeline.h \
	vulkan_renderpass.c vulkan_renderpass.h \
	vulkan_shader.c vulkan_shader.h \
	vulkan_swapchain.c vulkan_swapchain.h \
	vulkan_sync.c vulkan_sync.h \
	x11_mainloop.c x11_mainloop.h \
	x11_setup.c x11_setup.h \
	x11_vulkan.c x11_vulkan.h

bss2kdpy_LDADD = \
	frag.$(OBJEXT) \
	vert.$(OBJEXT)

EXTRA_DIST = \
	red.frag \
	triangle.vert

CLEANFILES = \
	frag.spv \
	vert.spv

.spv.$(OBJEXT):
	$(OBJCOPY) -I binary -O $(BFDTYPE) $< $@

frag.spv: red.frag
	$(GLSLANGVALIDATOR) -V $^

vert.spv: triangle.vert
	$(GLSLANGVALIDATOR) -V $^
