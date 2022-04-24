#pragma once

#include <stdbool.h>

struct global;

bool vulkan_setup(struct global *);
void vulkan_teardown(struct global *);
