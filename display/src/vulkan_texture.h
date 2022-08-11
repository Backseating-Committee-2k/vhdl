#pragma once

#include <stdbool.h>

struct global;

bool vulkan_texture_setup(struct global *g);
void vulkan_texture_teardown(struct global *g);
