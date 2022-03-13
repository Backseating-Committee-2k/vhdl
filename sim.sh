#! /bin/sh -x
set -e
ghdl -a --std=08 cpu.vhdl registers.vhdl tb_cpu.vhdl tb_cpu_sim.vhdl
ghdl -e --std=08 tb_cpu_sim
ghdl -r --std=08 tb_cpu_sim --wave=tb_cpu.ghw
