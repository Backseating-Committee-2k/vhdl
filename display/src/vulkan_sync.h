#pragma once

#include <stdbool.h>

struct global;

bool vulkan_sync_setup(struct global *g);
void vulkan_sync_teardown(struct global *g);
