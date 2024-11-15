#! /bin/sh -e

enable_tbbmalloc_workaround()
{
	LD_PRELOAD='/opt/${LIB}/hack.so'
	export LD_PRELOAD
}

disable_tbbmalloc_workaround()
{
	unset LD_PRELOAD
}

PATH=/opt/altera/16.1/quartus/bin:$PATH
if [ "$1" = "-r" ]; then
	if [ -z "$DISPLAY" ]; then
		if [ -z "`which xvfb-run`" ]; then
			echo >&2 "MegaWizard requires an X server."
			echo >&2
			echo >&2 "Either run from a graphical session or install xvfb"
			exit 1
		fi
		# reexec self under xvfb
		exec xvfb-run $0 "$*"
	fi
	./gen.sh
fi

enable_tbbmalloc_workaround

./syn.sh

disable_tbbmalloc_workaround
