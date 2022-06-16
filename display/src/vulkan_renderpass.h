#pragma once

#include <stdbool.h>

struct global;

bool vulkan_renderpass_setup(struct global *g);
void vulkan_renderpass_teardown(struct global *g);
