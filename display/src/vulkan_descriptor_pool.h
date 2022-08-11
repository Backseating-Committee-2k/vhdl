#pragma once

#include <stdbool.h>

struct global;

bool vulkan_descriptor_pool_setup(struct global *);
void vulkan_descriptor_pool_teardown(struct global *);
