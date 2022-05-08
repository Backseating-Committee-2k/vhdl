#! /bin/sh -x
set -e
if ! which quartus_sh 2>/dev/null; then
	PATH=/opt/altera/16.1/quartus/bin:$PATH
fi
quartus_sh --flow compile bss2k.qpf
