#! /bin/sh -x
set -e
ghdl -a --std=08 mem_arbiter.vhdl tb_mem_arbiter.vhdl
ghdl -e --std=08 tb_mem_arbiter
ghdl -r --std=08 tb_mem_arbiter --wave=tb_mem_arbiter.ghw

ghdl -a --std=08 cpu.vhdl registers.vhdl tb_cpu.vhdl tb_cpu_sim.vhdl
ghdl -e --std=08 tb_cpu_sim
ghdl -r --std=08 tb_cpu_sim --wave=tb_cpu.ghw
