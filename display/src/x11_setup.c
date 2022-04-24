#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_setup.h"

#include "bss2kdpy.h"

#include <X11/Xlib.h>

bool x11_setup(struct global *g)
{
	g->x11.display = XOpenDisplay(NULL);

	if(g->x11.display == NULL)
		goto fail;

	return true;

fail:
	x11_teardown(g);
	return false;
}

void x11_teardown(struct global *g)
{
	if(g->x11.display)
		XCloseDisplay(g->x11.display);
	g->x11.display = NULL;
}
