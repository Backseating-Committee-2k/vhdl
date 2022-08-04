#! /bin/sh -x
set -e
if ! which vlib 2>/dev/null; then
        PATH=/opt/altera/16.1/modelsim_ase/bin:$PATH
fi

cd simulation

rm -rf libraries
mkdir -p libraries
vlib libraries/work
vmap work libraries/work

vcom -2008 \
	modelsim/bss2k.vho \
	../board_phi/tb_timing_start_cpu.vhdl

vsim -l tb_timing_start_cpu.log -t ps -c -L altera_mf -sdftyp '/tb_timing_start_cpu/board_inst=modelsim/bss2k_vhd.sdo' tb_timing_start_cpu -do "vcd file tb_divider.vcd" -do "vcd add -r *" -do "run -a" -do "quit"

exit 0

simulation/modelsim/bss2k_6_1200mv_85c_slow.vho
simulation/modelsim/bss2k_6_1200mv_85c_vhd_slow.sdo
simulation/modelsim/bss2k_min_1200mv_0c_fast.vho
simulation/modelsim/bss2k_min_1200mv_0c_vhd_fast.sdo
simulation/modelsim/bss2k_modelsim.xrf
simulation/modelsim/bss2k_vhd.sdo
vsim -l tb_divider.log -t ps -c -L altera_mf tb_divider -do "vcd file tb_divider.vcd" -do "vcd add -r *" -do "run -a" -do "quit"
vsim -l tb_cpu_seq.log -t ps -c -L altera_mf tb_cpu_altera_seq -do "vcd file tb_cpu_seq.vcd" -do "vcd add -r *" -do "run -a" -do "quit"
vsim -l tb_cpu_pipe.log -t ps -c -L altera_mf tb_cpu_altera_pipe -do "vcd file tb_cpu_pipe.vcd" -do "vcd add -r *" -do "run -a" -do "quit"
