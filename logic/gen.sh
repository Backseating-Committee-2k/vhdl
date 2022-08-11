#! /bin/sh -x
set -e
if ! which quartus_sh 2>/dev/null; then
	PATH=/opt/altera/16.1/quartus/bin:$PATH
fi
qmegawiz -silent cpu/altera_registers.vhd

qmegawiz -silent board_phi/debug_fifo.vhd
qmegawiz -silent board_phi/debug_pll.vhd
qmegawiz -silent board_phi/debug_port.vhd

qmegawiz -silent board_phi/pll.vhd
qmegawiz -silent board_phi/pcie.vhd
qmegawiz -silent board_phi/pcie_serdes.vhd
qmegawiz -silent board_phi/pcie_reconfig.vhd

qmegawiz -silent board_phi/textmode_pixel_fifo.vhd
qmegawiz -silent board_phi/textmode_ram.vhd
qmegawiz -silent board_phi/textmode_rom.vhd

# patch frequency of fixedclk_serdes
sed -i -e '/fixedclk_serdes/s/100/125/' board_phi/pcie.sdc
# patch multicycle constraints for tl_cfg sampling
sed -i -e '/set_multicycle_path/s/tl_cfg_[a-z_]*/&_hip/' board_phi/pcie.sdc

# copy reset controller example
cp board_phi/pcie_examples/chaining_dma/pcie_rs_hip.vhd board_phi/
# copy tl_cfg sampling example
cp board_phi/pcie_examples/chaining_dma/altpcierd_tl_cfg_sample.vhd board_phi/
