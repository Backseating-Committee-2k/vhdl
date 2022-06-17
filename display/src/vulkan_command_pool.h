#pragma once

#include <stdbool.h>

struct global;

bool vulkan_command_pool_setup(struct global *g);
void vulkan_command_pool_teardown(struct global *g);
