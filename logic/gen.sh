#! /bin/sh -x
set -e
if ! which quartus_sh 2>/dev/null; then
	PATH=/opt/altera/16.1/quartus/bin:$PATH
fi
qmegawiz -silent cpu/altera_registers.vhd

qmegawiz -silent board_phi/pll.vhd
qmegawiz -silent board_phi/pcie.vhd
qmegawiz -silent board_phi/pcie_serdes.vhd
qmegawiz -silent board_phi/pcie_reconfig.vhd

# patch frequency of fixedclk_serdes
sed -i -e '/fixedclk_serdes/s/100/125/' board_phi/pcie.sdc

# copy reset controller example
cp board_phi/pcie_examples/chaining_dma/pcie_rs_hip.vhd board_phi/
