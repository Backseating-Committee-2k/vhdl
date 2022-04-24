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

	{
		/** @todo more than one screen */
		int const screen_number = DefaultScreen(g->x11.display);
		Screen *const screen = ScreenOfDisplay(
				g->x11.display, screen_number);
		Window const root = RootWindowOfScreen(screen);
		Visual *const visual = DefaultVisual(
				g->x11.display, screen_number);

		g->x11.window = XCreateWindow(
				/* display */	g->x11.display,
				/* parent */	root,
				/* x, y */	100, 100,
				/* w, h */	200, 200,
				/* border w */	0,
				/* depth */	CopyFromParent,
				/* class */	InputOutput,
				/* visual */	visual,
				/* valuemask */	0,
				/* attrib */	NULL);

		if(g->x11.window == None)
			goto fail;
	}

	return true;

fail:
	x11_teardown(g);
	return false;
}

void x11_teardown(struct global *g)
{
	if(g->x11.window != None)
		XDestroyWindow(g->x11.display, g->x11.window);
	g->x11.window = None;
	if(g->x11.display)
		XCloseDisplay(g->x11.display);
	g->x11.display = NULL;
}
