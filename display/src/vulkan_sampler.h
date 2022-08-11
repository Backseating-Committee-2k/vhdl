#pragma once

#include <stdbool.h>

struct global;

bool vulkan_sampler_setup(struct global *);
void vulkan_sampler_teardown(struct global *);
