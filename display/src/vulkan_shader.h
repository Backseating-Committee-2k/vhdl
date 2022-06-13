#pragma once

#include <stdbool.h>

struct global;

bool vulkan_shader_setup(struct global *g);
void vulkan_shader_teardown(struct global *g);
