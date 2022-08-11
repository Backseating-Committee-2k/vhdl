#pragma once

#include <stdbool.h>

struct global;

bool vulkan_external_texture_setup(struct global *g);
void vulkan_external_texture_teardown(struct global *g);
