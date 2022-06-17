#pragma once

#include <stdbool.h>

struct global;

bool vulkan_command_buffer_setup(struct global *g);
void vulkan_command_buffer_teardown(struct global *g);
