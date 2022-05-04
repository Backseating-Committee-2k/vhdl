#pragma once

#include <stdbool.h>

struct global;

bool vulkan_device_setup(struct global *);
void vulkan_device_teardown(struct global *);
