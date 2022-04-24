#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_mainloop.h"

#include "bss2kdpy.h"

#include <X11/Xlib.h>

#include <sys/types.h>
#include <sys/select.h>

#include <stddef.h>

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
			break;

		XEvent event;

		unsigned long const events = StructureNotifyMask|VisibilityChangeMask;

		while(XCheckMaskEvent(g->x11.display, events, &event))
			{ /* ignore event */ }
	}
	return true;
}
