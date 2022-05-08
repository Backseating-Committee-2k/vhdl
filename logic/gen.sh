#! /bin/sh -x
set -e
if ! which quartus_sh 2>/dev/null; then
	PATH=/opt/altera/16.1/quartus/bin:$PATH
fi
qmegawiz -silent cpu/altera_registers.vhd
