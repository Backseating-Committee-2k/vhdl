#pragma once

#include <stdbool.h>

struct global;

bool vulkan_descriptor_set_layout_setup(struct global *g);
void vulkan_descriptor_set_layout_teardown(struct global *g);
