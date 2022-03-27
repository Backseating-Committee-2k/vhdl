#! /bin/sh -x
set -e
ghdl -a --std=08 mem_arbiter.vhdl tb_mem_arbiter.vhdl
ghdl -e --std=08 tb_mem_arbiter
ghdl -r --std=08 tb_mem_arbiter --wave=tb_mem_arbiter.ghw

ghdl -a --std=08 cpu_sequential.vhdl registers.vhdl tb_cpu.vhdl tb_cpu_sim_seq.vhdl
ghdl -e --std=08 tb_cpu_sim_seq
ghdl -r --std=08 tb_cpu_sim_seq --wave=tb_cpu_seq.ghw
