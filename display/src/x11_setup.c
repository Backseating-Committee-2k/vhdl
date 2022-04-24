#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_setup.h"

#include "bss2kdpy.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>

bool x11_setup(struct global *g)
{
	/** @todo constants? */
	int const tex_width = 480;
	int const tex_height = 360;

	/* sensible defaults */
	g->canvas.x = 0;
	g->canvas.y = 0;
	g->canvas.w = tex_width;
	g->canvas.h = tex_height;

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

		XSetWindowAttributes attr =
		{
			.event_mask = StructureNotifyMask|VisibilityChangeMask
		};

		g->x11.window = XCreateWindow(
				/* display */	g->x11.display,
				/* parent */	root,
				/* x, y */	0, 0,
				/* w, h */	tex_width, tex_height,
				/* border w */	0,
				/* depth */	CopyFromParent,
				/* class */	InputOutput,
				/* visual */	visual,
				/* valuemask */	CWEventMask,
				/* attrib */	&attr);

		if(g->x11.window == None)
			goto fail;
	}

	{
		XSizeHints *size_hints = XAllocSizeHints();
		if(!size_hints)
			goto fail;

		size_hints->min_width = tex_width;
		size_hints->min_height = tex_height;
		size_hints->width_inc = tex_width;
		size_hints->height_inc = tex_height;
		size_hints->base_width = tex_width;
		size_hints->base_height = tex_height;
		size_hints->flags = PMinSize|PResizeInc|PBaseSize;

		XSetStandardProperties(
				g->x11.display,
				g->x11.window,
				"BSS2k Display",
				"BSS2k Display",
				None,
				g->argv,
				g->argc,
				size_hints);

		XFree(size_hints);

	}

	{
		XMapWindow(g->x11.display, g->x11.window);
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
