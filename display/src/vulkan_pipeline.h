#pragma once

#include <stdbool.h>

struct global;

bool vulkan_pipeline_setup(struct global *g);
void vulkan_pipeline_teardown(struct global *g);
