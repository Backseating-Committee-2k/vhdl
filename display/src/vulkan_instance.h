#pragma once

#include <stdbool.h>

struct global;

bool vulkan_instance_setup(struct global *);
void vulkan_instance_teardown(struct global *);
