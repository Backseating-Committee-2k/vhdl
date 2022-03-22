#! /bin/sh -x
set -e
if ! which vlib 2>/dev/null; then
        PATH=/opt/altera/20.1/modelsim_ase/bin:$PATH
fi

rm -rf work
vlib work
vcom -2008 altera_registers.vhd cpu.vhdl tb_cpu.vhdl tb_cpu_altera.vhdl
vsim -l tb_cpu.log -t ps -c -L altera_mf tb_cpu_altera -do "vcd file tb_cpu.vcd" -do "vcd add -r *" -do "run -a" -do "quit"
