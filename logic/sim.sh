#! /bin/sh -x
set -e
ghdl -a --std=08 cpu/bss2k.vhdl cpu/mem_arbiter.vhdl cpu/tb_mem_arbiter.vhdl
ghdl -e --std=08 tb_mem_arbiter
ghdl -r --std=08 tb_mem_arbiter --wave=tb_mem_arbiter.ghw

ghdl -a --std=08 \
	cpu/bss2k.vhdl \
	cpu/cpu_pipelined.vhdl \
	cpu/cpu_sequential.vhdl \
	cpu/registers.vhdl \
	cpu/tb_cpu.vhdl \
	cpu/tb_cpu_sim_pipe.vhdl \
	cpu/tb_cpu_sim_seq.vhdl
ghdl -e --std=08 tb_cpu_sim_seq
ghdl -r --std=08 tb_cpu_sim_seq --wave=tb_cpu_seq.ghw
ghdl -e --std=08 tb_cpu_sim_pipe
ghdl -r --std=08 tb_cpu_sim_pipe --wave=tb_cpu_pipe.ghw
