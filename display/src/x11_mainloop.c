#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "x11_mainloop.h"

#include <sys/types.h>
#include <sys/select.h>

#include <stddef.h>

bool x11_mainloop(struct global *g)
{
	(void)g;

	for(;;)
	{
		struct timespec timeout =
		{
			.tv_sec = 1,
			.tv_nsec = 0
		};

		int rc = pselect(
				0,
				NULL,
				NULL,
				NULL,
				&timeout,
				NULL);

		if(rc == 0)
			break;
	}
	return true;
}
