#! /bin/sh -x
set -e
if ! which vlib 2>/dev/null; then
        PATH=/opt/altera/16.1/modelsim_ase/bin:$PATH
fi

rm -rf work
vlib work
vcom -2008 \
	cpu/bss2k.vhdl \
	cpu/altera_registers.vhd \
	cpu/cpu_pipelined.vhdl \
	cpu/cpu_sequential.vhdl \
	cpu/tb_cpu.vhdl \
	cpu/tb_cpu_altera_pipe.vhdl \
	cpu/tb_cpu_altera_seq.vhdl
vsim -l tb_cpu_seq.log -t ps -c -L altera_mf tb_cpu_altera_seq -do "vcd file tb_cpu_seq.vcd" -do "vcd add -r *" -do "run -a" -do "quit"
vsim -l tb_cpu_pipe.log -t ps -c -L altera_mf tb_cpu_altera_pipe -do "vcd file tb_cpu_pipe.vcd" -do "vcd add -r *" -do "run -a" -do "quit"

vcom -2008 \
	board_phi/textmode_pixel_fifo.vhd \
	board_phi/textmode_ram.vhd \
	board_phi/textmode_rom.vhd \
	board_phi/textmode_output.vhdl \
	board_phi/tb_textmode_output.vhdl
vsim -l tb_textmode_output.log -t ps -c -L altera_mf tb_textmode_output -do "vcd file tb_textmode_output.vcd" -do "vcd add -r *" -do "run -a" -do "quit"
