#pragma once

#include <stdbool.h>

struct global;

bool vulkan_swapchain_update(struct global *g);
void vulkan_swapchain_teardown(struct global *g);
