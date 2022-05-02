#pragma once

#include <stdbool.h>

struct global;

bool x11_vulkan_setup(struct global *g);
void x11_vulkan_teardown(struct global *g);
