#pragma once

#include <stdbool.h>

struct global;

bool x11_setup(struct global *);
void x11_teardown(struct global *);
