#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_mainloop.h"

#include "bss2kdpy.h"

#include <X11/Xlib.h>

#include <sys/types.h>
#include <sys/select.h>

#include <stddef.h>

static void handle_visibility_event(struct global *g, XVisibilityEvent *event)
{
	switch(event->state)
	{
	case VisibilityUnobscured:
	case VisibilityPartiallyObscured:
		g->visible = true;
		break;
	case VisibilityFullyObscured:
		g->visible = false;
		break;
	}
}

static bool handle_destroy_event(struct global *g, XDestroyWindowEvent *event)
{
	if(event->window == g->x11.window)
	{
		g->x11.window = None;
		return false;
	}

	return true;
}

static void handle_unmap_event(struct global *g, XUnmapEvent *event)
{
	(void)event;

	g->mapped = false;

	XDestroyWindow(g->x11.display, g->x11.window);
}

static void handle_map_event(struct global *g, XMapEvent *event)
{
	(void)event;

	g->mapped = true;
}

static void handle_configure_event(struct global *g, XConfigureEvent *event)
{
	g->canvas.x = event->x;
	g->canvas.y = event->y;
	g->canvas.w = event->width;
	g->canvas.h = event->height;
}

static bool handle_event(struct global *g, XEvent *event)
{
	switch(event->type)
	{
	case VisibilityNotify:
		handle_visibility_event(g, (XVisibilityEvent *)event);
		break;
	case DestroyNotify:
		return handle_destroy_event(g, (XDestroyWindowEvent *)event);
	case UnmapNotify:
		handle_unmap_event(g, (XUnmapEvent *)event);
		break;
	case MapNotify:
		handle_map_event(g, (XMapEvent *)event);
		break;
	case ReparentNotify:
		/* nothing to do here */
		break;
	case ConfigureNotify:
		handle_configure_event(g, (XConfigureEvent *)event);
		break;
	}

	return true;
}

bool x11_mainloop(struct global *g)
{
	XFlush(g->x11.display);

	for(;;)
	{
		int x11_fd = ConnectionNumber(g->x11.display);

		int maxfd = -1;

		fd_set readfds;

		FD_ZERO(&readfds);
		FD_SET(x11_fd, &readfds);
		if(x11_fd > maxfd)
			maxfd = x11_fd;

		struct timespec timeout =
		{
			.tv_sec = 1,
			.tv_nsec = 0
		};

		int rc = pselect(
				maxfd + 1,
				&readfds,
				NULL,
				NULL,
				&timeout,
				NULL);

		if(rc == 0)
		{
			XUnmapWindow(
					g->x11.display,
					g->x11.window);
		}

		XEvent event;

		unsigned long const events = StructureNotifyMask|VisibilityChangeMask;

		bool stop = false;

		while(XCheckMaskEvent(g->x11.display, events, &event))
		{
			if(!handle_event(g, &event))
				stop = true;
		}

		if(stop)
			break;
	}
	return true;
}