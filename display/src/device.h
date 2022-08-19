#pragma once

#include <stdbool.h>

struct global;

bool device_setup(struct global *);
void device_teardown(struct global *);
