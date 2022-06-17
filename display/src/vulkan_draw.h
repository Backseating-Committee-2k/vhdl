#pragma once

#include <stdbool.h>

struct global;

bool vulkan_draw(struct global *g);
void vulkan_draw_stop(struct global *g);
