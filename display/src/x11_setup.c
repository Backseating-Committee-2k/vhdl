#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_setup.h"

#include "bss2kdpy.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include "util.h"

bool x11_setup(struct global *g)
{
	/** @todo constants? */
	int const tex_width = 480;
	int const tex_height = 360;

	g->shutdown = false;
	g->mapped = false;
	g->visible = false;
	g->drawing = false;

	/* sensible defaults */
	g->canvas.x = 0;
	g->canvas.y = 0;
	g->canvas.w = tex_width;
	g->canvas.h = tex_height;

	XInitThreads();

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

		int const screen_width = WidthOfScreen(screen);
		int const screen_height = HeightOfScreen(screen);

		int const scaling_factor = min(
				screen_width / tex_width,
				screen_height / tex_height);

		int const window_width = tex_width * scaling_factor;
		int const window_height = tex_height * scaling_factor;
		int const window_x = (screen_width - window_width) / 2;
		int const window_y = (screen_height - window_height) / 2;

		/* initialize position/size info with requested values. If
		 * the window manager doesn't override our choices, there
		 * won't be a ConfigureNotify, and these are what we go
		 * with during swapchain creation
		 */
		g->canvas.x = 0;
		g->canvas.y = 0;
		g->canvas.w = window_width;
		g->canvas.h = window_height;

		g->x11.window = XCreateWindow(
				/* display */	g->x11.display,
				/* parent */	root,
				/* x, y */	window_x, window_y,
				/* w, h */	window_width, window_height,
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
		size_hints->min_aspect.x = 4;
		size_hints->min_aspect.y = 3;
		size_hints->max_aspect.x = 4;
		size_hints->max_aspect.y = 3;
		size_hints->flags = PMinSize|PAspect;

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
