bin_PROGRAMS = bss2kdpy

bss2kdpy_SOURCES = \
	bss2kdpy.c bss2kdpy.h \
	util.h \
	vulkan_instance.c vulkan_instance.h \
	vulkan_device.c vulkan_device.h \
	vulkan_shader.c vulkan_shader.h \
	vulkan_swapchain.c vulkan_swapchain.h \
	x11_mainloop.c x11_mainloop.h \
	x11_setup.c x11_setup.h \
	x11_vulkan.c x11_vulkan.h

bss2kdpy_LDADD = \
	red.$(OBJEXT) \
	triangle.$(OBJEXT)

EXTRA_DIST = \
	red.frag \
	triangle.vert

CLEANFILES = \
	red.glsl \
	triangle.glsl

.glsl.$(OBJEXT):
	$(OBJCOPY) -I binary -O $(BFDTYPE) $< $@

.frag.glsl:
	cp $< $@

.vert.glsl:
	cp $< $@
